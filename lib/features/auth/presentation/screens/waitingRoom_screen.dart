import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/race_screen.dart';
import '../../../../core/services/signalr_service.dart';
import '../../../../core/services/storage_service.dart';
import '../providers/race_settings_provider.dart';
import 'dart:convert';
import 'dart:async'; // StreamSubscription için import ekliyorum
import 'package:http/http.dart' as http;
import 'package:my_flutter_project/features/auth/domain/models/leave_room_request.dart';
import '../../../../core/config/api_config.dart';
import '../screens/tabs.dart';
import 'package:my_flutter_project/features/auth/domain/models/room_participant.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  final int roomId;
  final DateTime? startTime;
  final String? activityType;
  final String? duration;

  const WaitingRoomScreen({
    super.key,
    required this.roomId,
    this.startTime,
    this.activityType,
    this.duration,
  });

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  late bool _hasStartTime;
  bool _isConnected = false;
  bool _isRaceStarting = false;
  List<RoomParticipant> _participants = [];
  String? _myUsername; // Kullanıcı adı
  String? _myEmail; // Email adresi
  String? _lastJoinedUser; // Son katılan kullanıcı

  // Fotoğraf önbelleği için harita ekliyoruz
  final Map<String, String?> _profilePictureCache = {};

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  // Odadan çıkış işlemi için yeni metot
  Future<void> _leaveRoom({bool showConfirmation = true}) async {
    // Kullanıcıdan onay al
    if (showConfirmation) {
      final bool confirm = await _showLeaveConfirmationDialog();
      if (!confirm) return;
    }

    try {
      setState(() {
        _isLoading = true; // Eğer varsa, bir loading state kullanılabilir
      });

      // 1. API üzerinden çıkış yap
      final bool apiSuccess = await _callLeaveRoomApi();

      // 2. SignalR üzerinden çıkış yap
      if (apiSuccess) {
        try {
          final signalRService = ref.read(signalRServiceProvider);
          await signalRService.leaveRaceRoom(widget.roomId);
        } catch (e) {
          debugPrint('❌ SignalR üzerinden odadan çıkarken hata: $e');
          // API başarılı olduğu için devam ediyoruz
        }
      }

      // 3. Stream aboneliklerini temizle
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();

      // 4. Ana sayfaya yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TabsScreen()),
          (route) => false, // Tüm geçmiş sayfaları temizle
        );
      }
    } catch (e) {
      debugPrint('❌ Odadan çıkış sırasında hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Odadan çıkış sırasında bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Onay dialogu göster
  Future<bool> _showLeaveConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odadan Çıkış'),
        content:
            const Text('Yarış odasından çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // LeaveRoom API isteği
  Future<bool> _callLeaveRoomApi() async {
    try {
      // Token al
      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        throw Exception('Kimlik doğrulama tokeni bulunamadı');
      }

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      // İstek gövdesi oluştur
      final leaveRequest = LeaveRoomRequest(raceRoomId: widget.roomId);

      // API isteği yap
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/RaceRoom/leaveRoom'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(leaveRequest.toJson()),
      );

      debugPrint('📤 LeaveRoom API cevabı: ${response.statusCode}');
      debugPrint('📄 API cevap body: ${response.body}');

      return response.statusCode == 200; // Başarılı mı?
    } catch (e) {
      debugPrint('❌ LeaveRoom API hatası: $e');
      throw e; // Üst metoda hatayı ilet
    }
  }

  @override
  void initState() {
    super.initState();
    _hasStartTime = widget.startTime != null;
    _participants = []; // Boş liste ile başlat
    debugPrint('🔄 WaitingRoom initState - Başlangıç durumu:');
    debugPrint('🏠 Oda ID: ${widget.roomId}');

    // Kullanıcı adını al
    _loadUsername();

    // SignalR bağlantısını başlat
    _setupSignalR().then((_) {
      // SignalR bağlantısı kurulduktan sonra ilk katılımcı listesini al
      if (_isConnected) {
        debugPrint('📥 İlk katılımcı listesi alınıyor...');
        ref.read(signalRServiceProvider).joinRaceRoom(widget.roomId);
      }
    });
  }

  Future<void> _loadUsername() async {
    try {
      final tokenJson = await StorageService.getToken();
      if (tokenJson != null) {
        final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
        final String token = tokenData['token'];

        // Token'ı parçalara ayır
        final parts = token.split('.');
        if (parts.length != 3) {
          throw Exception('Invalid JWT token format');
        }

        // Base64 encoded payload kısmını decode et
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decodedPayload = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> userData = jsonDecode(decodedPayload);

        debugPrint('Token payload içeriği: $userData');

        // Token'dan hem kullanıcı adını hem de email'i al
        if (userData.containsKey('Username')) {
          setState(() {
            _myUsername = userData['Username'].toString().trim();
          });
          debugPrint('Kendi kullanıcı adınız: $_myUsername');
        }

        if (userData.containsKey(
            'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress')) {
          setState(() {
            _myEmail = userData[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];
          });
          debugPrint('Kendi email adresiniz: $_myEmail');
        }

        // Eğer name claim'inden username alamadıysak, email'den oluşturalım
        if (_myUsername == null && _myEmail != null) {
          setState(() {
            _myUsername = _myEmail!.split('@')[0];
          });
          debugPrint('Email\'den kullanıcı adı oluşturuldu: $_myUsername');
        }
      }
    } catch (e) {
      debugPrint('Kullanıcı bilgisi yüklenirken hata: $e');
    }
  }

  Future<void> _setupSignalR() async {
    final signalRService = ref.read(signalRServiceProvider);

    try {
      // SignalR bağlantısını başlat
      await signalRService.connect();
      await signalRService.joinRaceRoom(widget.roomId);

      setState(() {
        _isConnected = signalRService.isConnected;
      });

      // Kullanıcı ayrılma olayını dinle
      _subscriptions.add(signalRService.userLeftStream.listen((leftUserName) {
        if (!mounted || _isRaceStarting) return;

        debugPrint('👋 Kullanıcı ayrıldı: $leftUserName');

        setState(() {
          // Katılımcı listesinden kullanıcıyı kaldır
          _participants =
              _participants.where((p) => p.userName != leftUserName).toList();
          // Önbellekten de profil fotoğrafını kaldır
          _profilePictureCache.remove(leftUserName);
        });

        _showInfoMessage('$leftUserName odadan ayrıldı');
      }));

      // Mevcut oda katılımcılarını dinle
      _subscriptions
          .add(signalRService.roomParticipantsStream.listen((participants) {
        if (!mounted || _isRaceStarting) return;

        debugPrint('🏠 WaitingRoom - Katılımcı Listesi Alındı');
        debugPrint(
            '📋 Gelen Katılımcılar: ${participants.map((p) => p.userName).join(", ")}');
        debugPrint('📊 Toplam Katılımcı Sayısı: ${participants.length}');

        setState(() {
          _participants = List<RoomParticipant>.from(participants);

          // Önbellekteki eski kullanıcıları temizle
          final currentUsernames = participants.map((p) => p.userName).toSet();
          _profilePictureCache.removeWhere(
              (username, _) => !currentUsernames.contains(username));

          // Yeni kullanıcıların fotoğraflarını önbelleğe al
          for (var participant in participants) {
            if (participant.profilePictureUrl != null) {
              _profilePictureCache[participant.userName] =
                  participant.profilePictureUrl;
            }
          }
        });

        // Yeni katılan kullanıcıyı belirle
        if (participants.isNotEmpty &&
            participants.last.userName != _lastJoinedUser) {
          setState(() {
            _lastJoinedUser = participants.last.userName;
          });

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _lastJoinedUser = null;
              });
            }
          });
        }
      }));

      // Yarış başlama olayını dinle ve geri sayım süresi sonunda otomatik geçiş yap
      _subscriptions.add(signalRService.raceStartingStream.listen((data) {
        if (!mounted || _isRaceStarting)
          return; // Eğer yarış başlama süreci başladıysa çıkış yap

        debugPrint('Yarış başlama olayı alındı: $data');
        final int roomId = data['roomId'];
        final int countdownSeconds =
            data['countdownSeconds'] ?? 10; // Varsayılan 4 saniye

        if (roomId == widget.roomId) {
          debugPrint(
              'Yarış başlıyor: Oda $roomId, $countdownSeconds saniye sonra');

          // Standart yarış başlama süreci - tüm telefonlarda aynı süre
          _startRaceCountdown(countdownSeconds);
        } else {
          debugPrint(
              'Başka bir oda için yarış başlıyor: $roomId (bizim oda: ${widget.roomId})');
        }
      }));

      // Doğrudan yarış başladı eventi
      // _subscriptions.add(signalRService.userJoinedStream.listen((username) {
      //   if (!mounted) return; // Mounted kontrolü

      //   debugPrint('Kullanıcı katıldı: $username');
      //   setState(() {
      //    if (!_participants.contains(username)) {
      //      _participants.add(username);
      //     _lastJoinedUser = username; // Son katılan kullanıcıyı kaydet

      // 3 saniye sonra vurguyu kaldır
      //     Future.delayed(const Duration(seconds: 5), () {
      //       if (mounted) {
      //         setState(() {
      //           _lastJoinedUser = null;
      //         });
      //       }
      //     });
      //   }
      // });
      //}));
    } catch (e) {
      debugPrint('SignalR bağlantı hatası: $e');
      _showErrorMessage('SignalR bağlantı hatası: $e');
    }
  }

  // Standardize edilmiş yarış başlatma fonksiyonu
  void _startRaceCountdown(int seconds) {
    // Eğer yarış başlatma süreci zaten başladıysa, tekrar başlatma
    if (_isRaceStarting) {
      debugPrint('⚠️ Yarış başlatma süreci zaten aktif, tekrar başlatılmadı');
      return;
    }

    debugPrint(
        '🕒 Yarış başlatma süreci başladı, $seconds saniye sonra başlayacak');

    setState(() {
      _isRaceStarting = true;
      _showInfoMessage('Yarış başlıyor! $seconds saniye içinde hazır olun.');
    });

    // Standart süre sonunda yarış ekranına geçiş yap
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted && _isRaceStarting) {
        debugPrint(
            '⏱️ Geri sayım süresi doldu, RaceScreen\'e geçiş yapılıyor...');
        _navigateToRaceScreen();
      }
    });
  }

  void _showInfoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToRaceScreen() async {
    debugPrint('🚀 1. WaitingRoom -> RaceScreen geçişi başlıyor');
    debugPrint('🚀 2. Mevcut _myUsername değeri: $_myUsername');

    // Eğer zaten RaceScreen'e geçiş başladıysa tekrar başlatma
    if (!mounted || _isRaceStarting == false) {
      debugPrint(
          '🚫 Geçiş zaten başlamış veya widget artık mounted değil. Geçiş iptal edildi.');
      return;
    }

    // Kullanıcı adı null ise, yüklemeyi deneyelim
    if (_myUsername == null) {
      debugPrint('🚀 3. _myUsername null olduğu için yükleme başlıyor');
      await _loadUsername();
      debugPrint(
          '🚀 4. _loadUsername çağrısı tamamlandı, yeni değer: $_myUsername');

      // Yükleme sonrası hala null ise, son çare olarak token'dan doğrudan okuyalım
      if (_myUsername == null) {
        debugPrint('🚀 5. Hala null, token\'dan okuma deneniyor');
        final tokenJson = await StorageService.getToken();
        debugPrint('🚀 6. Token değeri: $tokenJson');

        if (tokenJson != null) {
          final Map<String, dynamic> userData = jsonDecode(tokenJson);
          debugPrint('🚀 7. Token içeriği: $userData');

          if (userData.containsKey('username')) {
            setState(() {
              _myUsername = userData['username'];
            });
            debugPrint('🚀 8. Token\'dan username alındı: $_myUsername');
          } else if (userData.containsKey('email')) {
            final email = userData['email'];
            setState(() {
              _myUsername = email.contains('@') ? email.split('@')[0] : email;
            });
            debugPrint('🚀 9. Email\'den username oluşturuldu: $_myUsername');
          }
        } else {
          debugPrint('🚀 10. Token null geldi! Kullanıcı adı alınamadı');
          _showErrorMessage('Kullanıcı bilgileri alınamadı!');
          return; // Kullanıcı adı olmadan devam etmeyelim
        }
      }
    }

    if (mounted && _isRaceStarting) {
      debugPrint('🚀 11. RaceScreen\'e geçiş yapılıyor');
      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => RaceScreen(
              roomId: widget.roomId,
              myUsername: _myUsername,
              raceDuration: ref.read(raceSettingsProvider).duration,
              profilePictureCache: Map<String, String?>.from(
                  _profilePictureCache), // Cache'i burada da ekliyoruz
            ),
          ),
          (route) => false,
        );
      } catch (e) {
        debugPrint('🚨 RaceScreen\'e geçiş sırasında hata: $e');
        // Tekrar deneme mekanizması
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !Navigator.of(context).canPop()) {
              debugPrint('🔄 RaceScreen\'e geçiş tekrar deneniyor...');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => RaceScreen(
                    roomId: widget.roomId,
                    myUsername: _myUsername,        
                    raceDuration: ref.read(raceSettingsProvider).duration,
                    profilePictureCache: Map<String, String?>.from(
                        _profilePictureCache), // Cache'i burada da ekliyoruz
                  ),
                ),
                (route) => false,
              );
            }
          });
        }
      }
    } else {
      debugPrint(
          '🚫 14. Widget mounted değil veya navigasyon zaten başladı, geçiş yapılamadı');
    }
  }

  @override
  void dispose() {
    debugPrint('WaitingRoomScreen dispose ediliyor...');

    // Tüm stream subscriptionları temizle
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    debugPrint('WaitingRoomScreen dispose edildi - tüm dinleyiciler kapatıldı');
    // SignalR bağlantısını kapatmayın - RaceScreen'e geçilince orada tekrar kullanılacak
    super.dispose();
  }

  // Katılımcı listesini güncelleyen yardımcı metod
  void _updateParticipantsList(List<RoomParticipant> newParticipants) {
    if (!mounted) return;

    debugPrint('🔄 Katılımcı listesi güncelleniyor...');
    debugPrint('📋 Mevcut liste: $_participants');
    debugPrint('📋 Yeni liste: $newParticipants');

    // Öncelikle tüm gelen katılımcıların profil fotoğraflarını önbelleğe alalım
    for (var participant in newParticipants) {
      if (participant.profilePictureUrl != null) {
        _profilePictureCache[participant.userName] =
            participant.profilePictureUrl;
      }
    }

    setState(() {
      if (newParticipants.isEmpty && _myUsername != null) {
        // Eğer liste boşsa ve kullanıcı adı varsa, kendimizi ekleyelim
        _participants = [RoomParticipant(userName: _myUsername!)];
        debugPrint('👤 İlk kullanıcı olarak kendimi ekliyorum: $_myUsername');
      } else {
        // Liste boş değilse veya kullanıcı adı yoksa, gelen listeyi kullan
        // Ancak önbellekteki fotoğrafları yeni listeye dahil edelim
        _participants = newParticipants.map((participant) {
          // Eğer katılımcının profil fotoğrafı yoksa ama önbellekte varsa
          if (participant.profilePictureUrl == null &&
              _profilePictureCache.containsKey(participant.userName)) {
            // Önbellekten profil fotoğrafını alalım
            return RoomParticipant(
                userName: participant.userName,
                profilePictureUrl: _profilePictureCache[participant.userName]);
          }
          return participant;
        }).toList();
      }
      debugPrint('✅ Katılımcı listesi güncellendi: $_participants');
    });
  }

  // Kendime ait kullanıcı adı için özel bir stil
  Widget _buildParticipantChip(String username) {
    // Gelen username ile token'daki bilgileri karşılaştır
    // Email, username veya username@domain.com şeklinde gelebilir
    bool isMe = false;

    // 1. Direkt username karşılaştırması
    if (_myUsername != null &&
        username.toLowerCase() == _myUsername!.toLowerCase()) {
      isMe = true;
    }
    // 2. Email karşılaştırması
    else if (_myEmail != null &&
        username.toLowerCase() == _myEmail!.toLowerCase()) {
      isMe = true;
    }
    // 3. Email içinde username karşılaştırması (username@domain.com formatında ise)
    else if (_myUsername != null &&
        username.contains('@') &&
        username.split('@')[0].toLowerCase() == _myUsername!.toLowerCase()) {
      isMe = true;
    }
    // 4. Username içinde email karşılaştırması (eğer email username olarak geldiyse)
    else if (_myEmail != null &&
        _myEmail!.contains('@') &&
        _myEmail!.split('@')[0].toLowerCase() == username.toLowerCase()) {
      isMe = true;
    }

    debugPrint(
        'Username karşılaştırma: gelen=$username, my_username=$_myUsername, my_email=$_myEmail, isMe=$isMe');

    final bool isLastJoined = username == _lastJoinedUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      transform: isLastJoined
          ? (Matrix4.translationValues(0, -4, 0)..scale(1.05))
          : Matrix4.identity(),
      child: Chip(
        label: Text(
          isMe ? "$username (Ben)" : username,
          style: TextStyle(
            fontWeight:
                isMe || isLastJoined ? FontWeight.bold : FontWeight.normal,
            color: isMe ? Colors.black : Colors.black87,
          ),
        ),
        backgroundColor: isLastJoined
            ? const Color(0xFFC4FF62)
            : isMe
                ? const Color(0xFFC4FF62)
                : const Color(0xFFC4FF62).withOpacity(0.5),
        avatar: isLastJoined
            ? const Icon(Icons.person_add, size: 16)
            : isMe
                ? const Icon(Icons.person, size: 16)
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Race Settings Provider'ı izle
    final raceSettings = ref.watch(raceSettingsProvider);

    // Aktivite tipi ve süre bilgilerini al
    final String displayActivityType = widget.activityType ??
        (raceSettings.roomType?.contains('indoor') == true
            ? 'Indoor Koşu'
            : 'Outdoor Koşu');
    final String displayDurationFromNow = widget.duration ??
        (raceSettings.duration != null
            ? '${raceSettings.duration} Dakika'
            : '30 Dakika');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _leaveRoom(showConfirmation: true),
        ),
        title: Text(
          'Yarış Odası #${widget.roomId}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      // WillPopScope ekleyerek fiziksel geri tuşunu da kontrol edelim
      body: WillPopScope(
        onWillPop: () async {
          await _leaveRoom(showConfirmation: true);
          return false; // Gerçek pop işlemini biz ele alıyoruz
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFC4FF62),
                Color(0xFFC4FF62),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Arka plan daireleri
                Positioned.fill(
                  child: CustomPaint(
                    painter: CirclePatternPainter(),
                  ),
                ),

                // Ana içerik
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Activity Type Circle - Display the selected activity type
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon based on activity type
                                Icon(
                                    displayActivityType
                                            .toLowerCase()
                                            .contains('outdoor')
                                        ? Icons.directions_run
                                        : displayActivityType
                                                .toLowerCase()
                                                .contains('indoor')
                                            ? Icons.fitness_center
                                            : Icons.directions_run,
                                    size: 30,
                                    color: Colors.black),
                                const SizedBox(height: 4),
                                Text(
                                  displayActivityType,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Duration Circle - Display the selected duration
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer,
                                    size: 30, color: Colors.black),
                                const SizedBox(height: 4),
                                Text(
                                  displayDurationFromNow,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Koşucular Bekleniyor Circle
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people,
                                    size: 40, color: Colors.black),
                                SizedBox(height: 8),
                                Text(
                                  'Koşucular\nBekleniyor',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Kullanıcı Profil Fotoğrafları
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _participants.length,
                            itemBuilder: (context, index) {
                              final participant = _participants[index];
                              final isCurrentUser =
                                  participant.userName == _myUsername ||
                                      (participant.userName.contains('@') &&
                                          participant.userName.split('@')[0] ==
                                              _myUsername);

                              // Önbellekten kullanıcının fotoğraf URL'sini al
                              final profileUrl = participant
                                      .profilePictureUrl ??
                                  _profilePictureCache[participant.userName];

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: isCurrentUser
                                      ? const Color(0xFFC4FF62)
                                      : Colors.white,
                                  backgroundImage: profileUrl != null
                                      ? NetworkImage(profileUrl)
                                      : null,
                                  child: profileUrl == null
                                      ? Text(
                                          participant.userName.isNotEmpty
                                              ? participant.userName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: isCurrentUser
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Alt bilgi metni
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            'Oda dolduğunda yarış otomatik\nolarak başlayacak',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Diğer değişkenler
  bool _isLoading = false;
}

// Daire desenleri çizen custom painter sınıfı
class CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(25, 0, 0, 0)
      ..style = PaintingStyle.fill;

    // Ekran boyutuna göre dairelerin konumlarını belirleyelim
    final width = size.width;
    final height = size.height;

    // Rastgele konumlarda daireler çizelim
    final circles = [
      Offset(width * 0.2, height * 0.1),
      Offset(width * 0.6, height * 0.2),
      Offset(width * 0.3, height * 0.3),
      Offset(width * 0.7, height * 0.4),
      Offset(width * 0.1, height * 0.5),
      Offset(width * 0.5, height * 0.6),
      Offset(width * 0.8, height * 0.7),
    ];

    // Daireleri çiz
    for (var center in circles) {
      canvas.drawCircle(center, 75, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
