import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/race_provider.dart'; // RaceNotifier için import
import 'package:my_flutter_project/features/auth/presentation/providers/race_state.dart'; // RaceState için import
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
import '../widgets/user_profile_avatar.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Define colors from the image design
const Color _backgroundColor = Color(0xFF121212); // Very dark background
const Color _cardBackgroundColor =
    Color(0xFF1F3C18); // Dark green card background
const Color _primaryTextColor = Colors.white;
const Color _secondaryTextColor = Color(0xFFB0B0B0); // Grey for labels
const Color _accentColor = Color(0xFFC4FF62); // Bright green accent

class WaitingRoomScreen extends ConsumerStatefulWidget {
  final int roomId;
  final DateTime? startTime;
  final String? activityType;
  final int? duration;

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
  String? _lastJoinedUser;
  bool _isLoading = false; // Son katılan kullanıcı

  // Fotoğraf önbelleği için harita ekliyoruz
  final Map<String, String?> _profilePictureCache = {};

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
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

      // Yarış başlama olayını dinle
      _subscriptions.add(signalRService.raceStartingStream.listen((data) {
        debugPrint(
            '--- WaitingRoom: RaceStarting event RECEIVED --- Data: $data');

        if (!mounted) {
          debugPrint(
              '--- WaitingRoom: RaceStarting - Widget not mounted, skipping. ---');
          return;
        }
        // Yarış zaten UI tarafında başladıysa tekrar tetikleme (güvenlik)
        if (_isRaceStarting) {
          debugPrint(
              '--- WaitingRoom: RaceStarting - UI already starting, skipping notifier call. ---');
          return;
        }

        final int roomId = data['roomId'];
        final int countdownSeconds = data['countdownSeconds'] ?? 10;
        debugPrint(
            '--- WaitingRoom: RaceStarting - Parsed Room ID: $roomId, Countdown: $countdownSeconds ---');

        if (roomId == widget.roomId) {
          debugPrint(
              '--- WaitingRoom: RaceStarting - Event matches current room ID. ---');

          // --- SADECE NOTIFIER'I TETİKLE ---
          final raceNotifier = ref.read(raceNotifierProvider.notifier);
          final bool isIndoor =
              widget.activityType?.toLowerCase() == 'indoor' ||
                  widget.activityType?.toLowerCase() == 'İç Mekan';
          final int durationMinutes = widget.duration ?? 10;

          debugPrint(
              '--- WaitingRoom: RaceStarting - Preparing to call notifier. Email: $_myEmail, Indoor: $isIndoor, Duration: $durationMinutes ---');

          if (_myEmail == null) {
            debugPrint(
                '--- WaitingRoom: HATA - Kullanıcı email bilgisi null! Yarış başlatılamıyor. ---');
            _showErrorMessage(
                'Kullanıcı bilgileri yüklenemediği için yarış başlatılamadı.');
            return;
          }

          debugPrint(
              '--- WaitingRoom: >>> Calling raceNotifier.startRace... ---');
          raceNotifier.startRace(
            roomId: roomId,
            countdownSeconds: countdownSeconds,
            raceDurationMinutes: durationMinutes,
            isIndoorRace: isIndoor,
            userEmail: _myEmail!,
            initialProfileCache:
                Map<String, String?>.from(_profilePictureCache),
          );
          debugPrint('--- WaitingRoom: raceNotifier.startRace CALLED. ---');
          // --- TETİKLEME SONU ---

          // --- LOCAL STATE VE TIMER KALDIRILDI ---
          setState(() {
            _isRaceStarting = true; // Sadece genel mod için
          });

          debugPrint(
              '--- WaitingRoom: Local state/timer removed. Waiting for notifier state change for navigation. ---');
          // --- LOCAL STATE VE TIMER KALDIRILDI SONU ---
        } else {
          debugPrint(
              'WaitingRoom: Başka oda için yarış başlıyor: $roomId (bizim oda: ${widget.roomId})');
        }
      }));
    } catch (e) {
      debugPrint('SignalR bağlantı hatası: $e');
      _showErrorMessage('SignalR bağlantı hatası: $e');
    }
  }

  // Odadan çıkış işlemi için yeni metot
  Future<void> _leaveRoom({bool showConfirmation = true}) async {
    // Kullanıcıdan onay al
    if (showConfirmation) {
      final bool confirm = await _showLeaveConfirmationDialog();
      if (!confirm) return;
    }
    WakelockPlus.disable();
    debugPrint('Wakelock disabled for WaitingRoomScreen');

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
    WakelockPlus.disable();
    debugPrint('Wakelock disabled for WaitingRoomScreen');

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

      // Yarış tipini belirle (indoor/outdoor)
      final bool isIndoorRace =
          widget.activityType?.toLowerCase().contains('indoor') == true;
      debugPrint('🚀 Yarış tipi: ${isIndoorRace ? "Indoor" : "Outdoor"}');

      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => RaceScreen(
              roomId: widget.roomId,
              // myUsername: _myUsername, // Removed
              // profilePictureCache: Map<String, String?>.from(_profilePictureCache), // Removed
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
                    // myUsername: _myUsername, // Removed
                    // profilePictureCache: Map<String, String?>.from(_profilePictureCache), // Removed
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
    WakelockPlus.disable();
    debugPrint('Wakelock disabled for WaitingRoomScreen');

    // Tüm stream subscriptionları temizle
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    debugPrint('WaitingRoomScreen dispose edildi - tüm dinleyiciler kapatıldı');
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

  @override
  Widget build(BuildContext context) {
    // --- Notifier Dinleme ve Navigasyon ---
    ref.listen<RaceState>(raceNotifierProvider,
        (RaceState? previousState, RaceState newState) {
      // newState'in RaceState olduğundan eminiz.
      // previousState null olabilir (ilk dinleme anında).

      // Yarış durumu aktif hale geldiğinde (geri sayım bittiğinde) kontrol et
      if (previousState?.isPreRaceCountdownActive == true &&
          !newState.isPreRaceCountdownActive &&
          newState.isRaceActive) {
        debugPrint(
            '--- WaitingRoom: Notifier state changed to active race. Navigating to RaceScreen... ---');

        if (mounted) {
          // newState'den roomId null değilse devam et
          if (newState.roomId == null) {
            debugPrint(
                '--- WaitingRoom: HATA - newState.roomId null! Navigasyon yapılamıyor. ---');
            _showErrorMessage('Yarış bilgileri eksik, ekrana geçilemiyor.');
            return;
          }

          // --- KÜÇÜK BİR GECİKME EKLE ---
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              // Gecikme sonrası tekrar kontrol et
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => RaceScreen(
                    roomId: newState.roomId!,
                  ),
                ),
                (route) => false,
              );
            }
          });
          // --- GECİKME SONU ---
        }
      }
    });
    // --- Dinleme Sonu ---

    // --- RaceNotifier State'ini İzle ---
    final raceState = ref.watch(raceNotifierProvider);

    // final raceSettings = ref.watch(raceSettingsProvider); // REMOVE this - Use widget props directly
    // Use widget.activityType directly, provide default if null
    final String displayActivityType = widget.activityType ?? 'Bilinmiyor';
    // Use widget.duration directly, provide default if null
    final String displayDuration =
        widget.duration != null ? '${widget.duration} dakika' : 'Belirsiz';

    // --- Subtitle Text'i _isRaceStarting ve Notifier State'ine Göre Al ---
    final String subtitleText;
    if (_isRaceStarting) {
      // Geri sayım süreci başladı mı?
      if (raceState.isPreRaceCountdownActive &&
          raceState.preRaceCountdownValue > 0) {
        // Geri sayım aktif ve devam ediyor
        subtitleText = 'Yarış Başlıyor ${raceState.preRaceCountdownValue}';
      } else {
        // Geri sayım bitti (veya henüz başlamadı ama _isRaceStarting true oldu)
        subtitleText = 'Yarış Başladı';
      }
    } else {
      // Geri sayım süreci hiç başlamadı
      subtitleText = 'Diğer yarışmacılar bekleniyor...';
    }
    // --- Subtitle Text Logic Sonu ---

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: WillPopScope(
        onWillPop: () async {
          await _leaveRoom(showConfirmation: true);
          return false; // Prevent default back navigation
        },
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Stretch elements horizontally
              children: [
                // Title
                const Text(
                  'Yarış Başlamak Üzere',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: _accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 30),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: _cardBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçilen Yarış Tipi',
                        style: TextStyle(
                          fontSize: 14,
                          color: _secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayActivityType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Yarış Süresi',
                        style: TextStyle(
                          fontSize: 14,
                          color: _secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: _accentColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            displayDuration,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Central Image
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0), // Padding for image
                    child: Image.asset(
                      'assets/images/waiting.png', // Use provided asset
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Participants Card
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    color: _cardBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hazır Olan Yarışmacılar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Stacked Profile Pictures
                      _buildParticipantAvatars(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Leave Button
                if (!_isLoading) // Hide button while loading/leaving
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _leaveRoom(showConfirmation: true),
                      icon: const Icon(Icons.exit_to_app, color: _accentColor),
                      label: const Text(
                        'Yarıştan Çık',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                // Loading indicator
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15.0),
                    child: Center(
                        child: CircularProgressIndicator(color: _accentColor)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for stacked participant avatars
  Widget _buildParticipantAvatars() {
    const double avatarRadius = 20.0;
    const double overlap = 15.0; // How much avatars overlap
    final int maxVisibleAvatars = 5; // Show max 5 avatars + overflow indicator

    List<Widget> avatarWidgets = [];
    int visibleCount = _participants.length > maxVisibleAvatars
        ? maxVisibleAvatars
        : _participants.length;

    // Ensure we only try to access participants if the list is not empty
    if (_participants.isNotEmpty) {
      for (int i = 0; i < visibleCount; i++) {
        final participant = _participants[i];
        // Get profile URL from participant or cache
        final profileUrl = participant.profilePictureUrl ??
            _profilePictureCache[participant.userName];

        avatarWidgets.add(
          Positioned(
            left: i * (avatarRadius * 2 - overlap),
            // Use UserProfileAvatar wrapped with a border CircleAvatar
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: _accentColor, // Border color
              child: UserProfileAvatar(
                imageUrl: profileUrl, // Pass the URL
                radius: avatarRadius - 2, // Inner radius
              ),
            ),
          ),
        );
      }
    }

    // Add overflow indicator if more participants exist
    if (_participants.length > maxVisibleAvatars) {
      avatarWidgets.add(
        Positioned(
          left: maxVisibleAvatars * (avatarRadius * 2 - overlap),
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: _secondaryTextColor,
            child: Text(
              '+${_participants.length - maxVisibleAvatars}',
              style: const TextStyle(
                  color: _backgroundColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    // Calculate the total width required for the stack
    double stackWidth = _participants.isEmpty
        ? 0
        : (visibleCount * (avatarRadius * 2 - overlap)) +
            overlap +
            (_participants.length > maxVisibleAvatars
                ? (avatarRadius * 2)
                : 0) -
            (_participants.length > maxVisibleAvatars ? overlap : 0);

    // Handle case where stackWidth might be zero or negative if no participants
    if (stackWidth <= 0 && _participants.isNotEmpty) {
      stackWidth = avatarRadius * 2; // Minimum width for one avatar
    } else if (stackWidth <= 0 && _participants.isEmpty) {
      return const SizedBox(
          height: avatarRadius * 2); // Return empty space if no participants
    }

    return Container(
      height: avatarRadius * 2, // Height of the avatar row
      // Ensure the container has a minimum width if there are avatars
      width: stackWidth > 0 ? stackWidth : null,
      constraints: BoxConstraints(
          minWidth: stackWidth > 0 ? stackWidth : 0), // Add constraints
      child: Stack(
        children: avatarWidgets,
      ),
    );
  }
}
