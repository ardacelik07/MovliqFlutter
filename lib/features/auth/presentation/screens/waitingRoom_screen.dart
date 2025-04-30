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
import '../widgets/user_profile_avatar.dart';

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
  String? _lastJoinedUser;
  bool _isLoading = false; // Son katılan kullanıcı

  // Fotoğraf önbelleği için harita ekliyoruz
  final Map<String, String?> _profilePictureCache = {};

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  // State variables for countdown
  Timer? _countdownTimer;
  int? _countdownSeconds;

  // Odadan çıkış işlemi için yeni metot
  Future<void> _leaveRoom({bool showConfirmation = true}) async {
    // Kullanıcıdan onay al
    if (showConfirmation) {
      final bool confirm = await _showLeaveConfirmationDialog();
      if (!confirm) return;
    }

    _countdownTimer?.cancel(); // Cancel timer if leaving

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
            data['countdownSeconds'] ?? 10; // Varsayılan 10 saniye

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
      _countdownSeconds = seconds; // Set initial countdown value
    });

    _countdownTimer?.cancel(); // Cancel previous timer if any
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds != null && _countdownSeconds! > 0) {
          _countdownSeconds = _countdownSeconds! - 1;
          debugPrint('⏳ Geri sayım: $_countdownSeconds');
        } else {
          timer.cancel();
          debugPrint('⏱️ Geri sayım timer\'ı tamamlandı.');
          // Navigation is handled by the separate Future.delayed
        }
      });
    });

    // Schedule navigation (this delay determines when navigation actually happens)
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted && _isRaceStarting) {
        debugPrint(
            '⏱️ Geri sayım süresi doldu, RaceScreen\'e geçiş yapılıyor...');
        _countdownTimer
            ?.cancel(); // Ensure timer is cancelled before navigating
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

    // !!! YENİ EKLENEN KOD BAŞLANGICI !!!
    // RaceScreen'e gitmeden ÖNCE Flutter SignalR bağlantısını kes
    try {
      debugPrint('🔌 Flutter SignalR bağlantısı kesiliyor...');
      final signalRService = ref.read(signalRServiceProvider);
      await signalRService.disconnect(); // VEYA resetConnection() ?
      debugPrint('🔌 Flutter SignalR bağlantısı başarıyla kesildi.');
    } catch (e) {
      debugPrint('🔌 Flutter SignalR bağlantısını keserken hata: $e');
      // Hata olsa bile devam etmeye çalışalım?
    }
    // !!! YENİ EKLENEN KOD SONU !!!

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

      // Yarış tipini belirle (indoor/outdoor)
      final raceSettings = ref.read(raceSettingsProvider);
      final bool isIndoorRace =
          raceSettings.roomType?.toLowerCase().contains('indoor') ?? false;
      debugPrint('🚀 Yarış tipi: ${isIndoorRace ? "Indoor" : "Outdoor"}');

      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => RaceScreen(
              roomId: widget.roomId,
              myUsername: _myUsername,
              raceDuration: ref.read(raceSettingsProvider).duration,
              profilePictureCache: Map<String, String?>.from(
                  _profilePictureCache), // Cache'i burada da ekliyoruz
              isIndoorRace: isIndoorRace, // Indoor/Outdoor tipini iletiyoruz
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
                    isIndoorRace:
                        isIndoorRace, // Indoor/Outdoor tipini iletiyoruz
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

    debugPrint(
        'WaitingRoomScreen dispose edildi - tüm dinleyiciler ve timer kapatıldı');
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

  @override
  Widget build(BuildContext context) {
    final raceSettings = ref.watch(raceSettingsProvider);
    final String displayActivityType = widget.activityType ??
        (raceSettings.roomType?.toLowerCase().contains('indoor') == true
            ? 'İç Mekan' // Simplified text
            : 'Dış Mekan'); // Simplified text
    final String displayDuration = widget.duration ??
        (raceSettings.duration != null
            ? '${raceSettings.duration} dakika' // Lowercase 'd'
            : 'Belirsiz'); // Default if null

    // Determine subtitle text based on countdown state
    final String subtitleText =
        (_countdownSeconds != null && _countdownSeconds! > 0)
            ? 'Yarış Başlıyor $_countdownSeconds'
            : 'Diğer yarışmacılar bekleniyor...';

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
