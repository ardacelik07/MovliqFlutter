import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/race_screen.dart';
import '../../../../core/services/signalr_service.dart';
import '../../../../core/services/storage_service.dart';
import '../providers/race_settings_provider.dart';
import 'dart:convert';
import 'dart:async'; // StreamSubscription için import ekliyorum

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
  List<String> _participants = [];
  String? _myUsername; // Kullanıcı adı
  String? _myEmail; // Email adresi
  String? _lastJoinedUser; // Son katılan kullanıcı

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

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

      // Liderlik tablosu güncellemelerini dinle (katılımcıların odaya katıldığını gösterir)
      _subscriptions.add(signalRService.leaderboardStream.listen((leaderboard) {
        if (!mounted || _isRaceStarting)
          return; // Eğer yarış başlama süreci başladıysa çıkış yap

        debugPrint(
            '📊 Liderlik tablosu güncellendi! Katılımcı sayısı: ${leaderboard.length}');

        // Artık burada _participants'ı güncellemeyelim, sadece debug için yazdıralım
        final leaderboardUsers =
            leaderboard.map((participant) => participant.userName).toList();
        debugPrint('📋 Liderlik tablosundaki kullanıcılar: $leaderboardUsers');
        debugPrint('👤 Benim kullanıcı adım: $_myUsername');

        // Oda maksimum katılımcı sayısına ulaştı mı kontrol edelim (3 kişi)
        const int maxParticipants = 3;
        if (leaderboard.length >= maxParticipants) {
          debugPrint(
              '🔄 Oda doldu (${leaderboard.length} kişi)! Otomatik yarış başlatılıyor...');
          // Standart yarış başlama süreci - tüm telefonlarda aynı süre
          _startRaceCountdown(4); // Tüm telefonlarda 4 saniye bekle
        }
      }));

      // Mevcut oda katılımcılarını dinle
      _subscriptions
          .add(signalRService.roomParticipantsStream.listen((participants) {
        if (!mounted || _isRaceStarting)
          return; // Eğer yarış başlama süreci başladıysa çıkış yap

        debugPrint('🏠 WaitingRoom - Katılımcı Listesi Alındı');
        debugPrint('📋 Gelen Katılımcılar: ${participants.join(", ")}');
        debugPrint('📊 Toplam Katılımcı Sayısı: ${participants.length}');

        _updateParticipantsList(participants);

        // Yeni katılan kullanıcıyı belirle
        if (participants.isNotEmpty && participants.last != _lastJoinedUser) {
          setState(() {
            _lastJoinedUser = participants.last;
          });

          // 3 saniye sonra yeni katılan kullanıcı vurgusunu kaldır
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _lastJoinedUser = null;
              });
            }
          });
        }

        // Oda maksimum katılımcı sayısına ulaştı mı kontrol edelim - Burada 3 kişi olarak değiştirildi
        const int maxParticipants = 3;
        if (participants.length >= maxParticipants) {
          debugPrint(
              '🔄 Oda doldu (${participants.length} kişi)! Otomatik yarış başlatılıyor...');

          // Standart yarış başlama süreci - tüm telefonlarda aynı süre
          _startRaceCountdown(10); // Tüm telefonlarda 4 saniye bekle
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
      _subscriptions.add(signalRService.raceStartedStream.listen((_) {
        if (!mounted || _isRaceStarting)
          return; // Eğer yarış başlama süreci başladıysa çıkış yap

        debugPrint(
            '🏁 Yarış başladı eventi alındı! Yarış ekranına geçiliyor...');

        // Standart yarış başlama süreci - tüm telefonlarda aynı süre
        _startRaceCountdown(4); // Tüm telefonlarda 4 saniye bekle
      }));

      // Kullanıcı katılma/ayrılma olaylarını dinle
      _subscriptions.add(signalRService.userJoinedStream.listen((username) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint('Kullanıcı katıldı: $username');
        setState(() {
          if (!_participants.contains(username)) {
            _participants.add(username);
            _lastJoinedUser = username; // Son katılan kullanıcıyı kaydet

            // 3 saniye sonra vurguyu kaldır
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _lastJoinedUser = null;
                });
              }
            });
          }
        });
      }));

      _subscriptions.add(signalRService.userLeftStream.listen((username) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint('Kullanıcı ayrıldı: $username');
        setState(() {
          _participants.remove(username);
        });
        _showInfoMessage('$username odadan ayrıldı');
      }));
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

    // Son bir kontrol yapalım
    if (_myUsername == null) {
      debugPrint('🚀 11. Tüm denemelere rağmen kullanıcı adı alınamadı!');
      _showErrorMessage('Kullanıcı adı alınamadı, lütfen tekrar giriş yapın');
      return;
    }

    // Geçiş sırasında hata oluşmaması için bir kontrol daha ekleyelim
    if (!mounted) {
      debugPrint('🚫 Widget artık mounted değil. Geçiş iptal edildi.');
      return;
    }

    debugPrint(
        '🚀 12. RaceScreen\'e geçiş yapılıyor, kullanıcı adı: $_myUsername');

    // Mevcut bildirimleri temizle
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    // Geçiş işlemine başladıysak bir flag ile kontrol et
    bool navigationStarted = false;

    if (mounted && !navigationStarted) {
      navigationStarted = true;

      try {
        debugPrint('🚀 13. Navigator.pushReplacement çağrılıyor...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RaceScreen(
              roomId: widget.roomId,
              myUsername: _myUsername,
              raceDuration: ref.read(raceSettingsProvider).duration,
            ),
          ),
        );
        debugPrint('🚀 14. RaceScreen\'e geçiş tamamlandı');
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
  void _updateParticipantsList(List<String> newParticipants) {
    if (!mounted) return;

    debugPrint('🔄 Katılımcı listesi güncelleniyor...');
    debugPrint('📋 Mevcut liste: $_participants');
    debugPrint('📋 Yeni liste: $newParticipants');

    setState(() {
      if (newParticipants.isEmpty && _myUsername != null) {
        // Eğer liste boşsa ve kullanıcı adı varsa, kendimizi ekleyelim
        _participants = [_myUsername!];
        debugPrint('👤 İlk kullanıcı olarak kendimi ekliyorum: $_myUsername');
      } else {
        // Liste boş değilse veya kullanıcı adı yoksa, gelen listeyi kullan
        _participants = List<String>.from(newParticipants);
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
    // Default values if not provided
    final String displayActivityType = widget.activityType ?? 'Outdoor Koşu';
    final String displayDuration = widget.duration ?? '30 Dakika';

    return Scaffold(
      body: Container(
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
              Positioned(
                left: 42.0, // Rastgele x değeri
                top: 75.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 110.0, // Rastgele x değeri
                top: 180.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 65.0, // Rastgele x değeri
                top: 285.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 175.0, // Rastgele x değeri
                top: 370.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 30.0, // Rastgele x değeri
                top: 470.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 135.0, // Rastgele x değeri
                top: 575.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 210.0, // Rastgele x değeri
                top: 680.0, // Rastgele y değeri
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 0, 0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(0, 0, 0, 0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Main content in vertical layout (original Column)
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
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
                            displayDuration,
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
                  const SizedBox(height: 40),
                  // Koşucular Bekleniyor Circle
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 40, color: Colors.black),
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
                  const SizedBox(height: 40),
                  // Kullanıcı Profil Fotoğrafları
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount:
                          _participants.length + 3, // 3 tane boş yer ekledik
                      itemBuilder: (context, index) {
                        if (index < _participants.length) {
                          // Mevcut katılımcılar için
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white,
                              child: Text(
                                _participants[index][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        } else {
                          // Boş yerler için
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white.withOpacity(0.3),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Alt bilgi metni
                  const Text(
                    'Oda dolduğunda yarış otomatik\nolarak başlayacak',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
