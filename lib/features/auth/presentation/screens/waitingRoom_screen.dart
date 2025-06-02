import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/race_provider.dart'; // RaceNotifier için import
import 'package:my_flutter_project/features/auth/presentation/providers/race_state.dart'; // RaceState için import
import 'package:my_flutter_project/features/auth/presentation/screens/race_screen.dart';
import '../../../../core/services/signalr_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/http_interceptor.dart'; // Added HttpInterceptor import
import '../providers/race_settings_provider.dart';
import 'dart:convert';
import 'dart:async'; // StreamSubscription için import ekliyorum
import 'dart:io'; // Platform için import
import 'package:http/http.dart' as http;
import 'package:my_flutter_project/features/auth/domain/models/leave_room_request.dart';
import '../../../../core/config/api_config.dart';
import '../screens/tabs.dart';
import 'package:my_flutter_project/features/auth/domain/models/room_participant.dart';
import '../widgets/user_profile_avatar.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart'; // MethodChannel için
import 'package:geolocator/geolocator.dart'; // Location servisleri için
import '../providers/race_coin_tracker_provider.dart';
import '../providers/user_data_provider.dart'; // Eğer yoksa ekle
import 'package:share_plus/share_plus.dart'; // SharePlus paketi eklendi
import 'package:flutter/rendering.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/leave_widget.dart'; // LeaveWidget importu
import 'package:flutter/widgets.dart'; // WidgetsBindingObserver için
import '../widgets/font_widget.dart'; // Added FontWidget import

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
  final String roomCode;
  final bool isHost;

  const WaitingRoomScreen({
    super.key,
    required this.roomId,
    required this.roomCode,
    required this.isHost,
    this.startTime,
    this.activityType,
    this.duration,
  });

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen>
    with WidgetsBindingObserver {
  late bool _hasStartTime;
  bool _isConnected = false;
  List<RoomParticipant> _participants = [];
  String? _myUsername; // Kullanıcı adı
  String? _myEmail; // Email adresi
  String? _lastJoinedUser;
  bool _isLoading = false; // Son katılan kullanıcı
  bool _isLoadingStartRace = false;

  // Fotoğraf önbelleği için harita ekliyoruz
  final Map<String, String?> _profilePictureCache = {};

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  // Listen for race state changes to detect race starting
  bool _navigationTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _hasStartTime = widget.startTime != null;
    _participants = []; // Boş liste ile başlat

    // Kullanıcı adını al
    _loadUsername().then((_) {
      _storeBeforeRaceCoin();
    });

    // SignalR bağlantısını başlat
    _setupSignalR().then((_) {
      // SignalR bağlantısı kurulduktan sonra ilk katılımcı listesini al
      if (_isConnected) {
        ref.read(signalRServiceProvider).joinRaceRoom(widget.roomId);
      }
    });
  }

  Future<void> _storeBeforeRaceCoin() async {
    // userDataProvider'dan mevcut coin'i almayı dene
    // valueOrNull kullanmak state null ise hata vermez
    final currentUserData = ref.read(userDataProvider).valueOrNull;
    if (currentUserData != null && currentUserData.coins != null) {
      ref
          .read(raceCoinTrackingProvider.notifier)
          .setBeforeRaceCoin(currentUserData.coins!);
    } else {
      // Eğer veri henüz yoksa veya coin null ise, kısa bir süre bekleyip tekrar dene
      // Veya fetchCoins tetiklenebilir ama bu karmaşıklaştırabilir.
      // Şimdilik sadece loglayalım.

      // İsteğe bağlı: Future.delayed ile tekrar deneme eklenebilir
    }
  }

  Future<void> _loadUsername() async {
    try {
      final tokenJson = await StorageService.getToken();
      if (tokenJson != null) {
        final String token = tokenJson;

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

        // Token'dan hem kullanıcı adını hem de email'i al
        if (userData.containsKey('Username')) {
          setState(() {
            _myUsername = userData['Username'].toString().trim();
          });
        }

        if (userData.containsKey(
            'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress')) {
          setState(() {
            _myEmail = userData[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];
          });
        }

        // Eğer name claim'inden username alamadıysak, email'den oluşturalım
        if (_myUsername == null && _myEmail != null) {
          setState(() {
            _myUsername = _myEmail!.split('@')[0];
          });
        }
      }
    } catch (e) {}
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
        if (!mounted) return;

        setState(() {
          // Katılımcı listesinden kullanıcıyı kaldır
          _participants =
              _participants.where((p) => p.userName != leftUserName).toList();
          // Önbellekten de profil fotoğrafını kaldır
          _profilePictureCache.remove(leftUserName);
        });
      }));

      // Mevcut oda katılımcılarını dinle
      _subscriptions
          .add(signalRService.roomParticipantsStream.listen((participants) {
        if (!mounted) return;

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

      // Yarış başlama olayını dinle (Bu artık RaceAlreadyStarted olarak düşünülmeli)
      _subscriptions.add(signalRService.raceStartingStream.listen((data) {
        if (!mounted) {
          return;
        }

        final int roomId = data['roomId'];
        final bool isRaceReallyAlreadyStarted =
            data['isRaceAlreadyStarted'] as bool? ?? false;
        final raceNotifier = ref.read(raceNotifierProvider.notifier);
        final String activityLower = widget.activityType?.toLowerCase() ?? '';
        final bool isIndoor = activityLower.contains('indoor') ||
            activityLower.contains('iç mekan');
        final int durationMinutes = widget.duration ?? 10; // Varsayılan süre

        if (_myEmail == null) {
          return;
        }

        if (roomId == widget.roomId) {
          if (isRaceReallyAlreadyStarted) {
            // --- DEVAM EDEN YARIŞA KATILMA SENARYOSU ---
            final double? remainingTimeForOngoingRace =
                data['remainingTimeSeconds'] as double?;
            if (remainingTimeForOngoingRace != null) {
              raceNotifier.startRace(
                roomId: roomId,
                countdownSeconds: 0, // Devam eden yarış için geri sayım yok
                raceDurationMinutes: durationMinutes,
                isIndoorRace: isIndoor,
                userEmail: _myEmail!,
                initialProfileCache:
                    Map<String, String?>.from(_profilePictureCache),
                initialRemainingTimeSeconds: remainingTimeForOngoingRace,
              );
            } else {}
          } else {
            // --- NORMAL YARIŞ BAŞLANGICI SENARYOSU ---
            final int countdownSeconds = data['countdownSeconds'] ?? 10;

            raceNotifier.startRace(
              roomId: roomId,
              countdownSeconds: countdownSeconds, // Sunucudan gelen geri sayım
              raceDurationMinutes: durationMinutes,
              isIndoorRace: isIndoor,
              userEmail: _myEmail!,
              initialProfileCache:
                  Map<String, String?>.from(_profilePictureCache),
              initialRemainingTimeSeconds:
                  null, // Yeni yarış için kalan süre yok
            );
          }
        } else {}
      }));

      // --- YENİ: Yeniden Bağlanma Olayını Dinle ---
      /*_subscriptions.add(
          signalRService.reconnectedStream.listen((String? newConnectionId) {
        if (newConnectionId != null && mounted) {
         
         
          try {
            signalRService.joinRaceRoom(widget.roomId).then((_) {
             
              // Katılımcı listesini yenilemek için bir flag veya metod çağrısı eklenebilir.
              // Şimdilik joinRaceRoom'un sunucudan RoomParticipants göndermesini bekliyoruz.
            }).catchError((e) {

            });
          } catch (e) {
           
          }
        }
      }));*/
    } catch (e) {}
  }

  // Odadan çıkış işlemi için yeni metot
  Future<void> _leaveRoom({bool showConfirmation = true}) async {
    // Kullanıcıdan onay al
    if (showConfirmation) {
      final bool confirm = await _showLeaveConfirmationDialog();
      if (!confirm) return;
    }
    WakelockPlus.disable();

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
        WakelockPlus.disable();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TabsScreen()),
          (route) => false, // Tüm geçmiş sayfaları temizle
        );
      }
    } catch (e) {
      if (mounted) {}
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
    // Yeni LeaveWidget'ı kullan
    final String leaveMessage = widget.roomCode.isNotEmpty
        ? 'Yarışı tamamlamadan çıkarsan, yatırdığın mCoin iade edilmez ve yarış dışı kalırsın.'
        : 'Odadan çıkmak istediğine emin misin?'; // Oda kodu yoksa daha genel bir mesaj

    final result = await showLeaveConfirmationDialog(
      context: context,
      imagePath: 'assets/images/leaveimage.png', // Belirttiğiniz resim yolu
      title: 'Odadan Ayrılmak İstiyor Musun?',
      message: leaveMessage, // Dinamik mesaj
      // confirmButtonText ve cancelButtonText varsayılan değerleri kullanacak ('Çıkış Yap', 'Devam Et')
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

      final String token = tokenJson;

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

      return response.statusCode == 200; // Başarılı mı?
    } catch (e) {
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

  void _navigateToRaceScreen() async {
    // Eğer zaten RaceScreen'e geçiş başladıysa tekrar başlatma
    if (!mounted) {
      return;
    }
    WakelockPlus.disable();

    // Kullanıcı adı null ise, yüklemeyi deneyelim
    if (_myUsername == null) {
      await _loadUsername();

      // Yükleme sonrası hala null ise, son çare olarak token'dan doğrudan okuyalım
      if (_myUsername == null) {
        final tokenJson = await StorageService.getToken();

        if (tokenJson != null) {
          final Map<String, dynamic> userData = jsonDecode(tokenJson);

          if (userData.containsKey('username')) {
            setState(() {
              _myUsername = userData['username'];
            });
          } else if (userData.containsKey('email')) {
            final email = userData['email'];
            setState(() {
              _myUsername = email.contains('@') ? email.split('@')[0] : email;
            });
          }
        } else {
          return; // Kullanıcı adı olmadan devam etmeyelim
        }
      }
    }

    if (mounted) {
      // Yarış tipini belirle (indoor/outdoor)
      final bool isIndoorRace =
          widget.activityType?.toLowerCase().contains('indoor') == true;

      try {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => RaceScreen(
              roomId: widget.roomId,
            ),
          ),
          (route) => false,
        );
      } catch (e) {
        // Tekrar deneme mekanizması
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !Navigator.of(context).canPop()) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => RaceScreen(
                    roomId: widget.roomId,
                  ),
                ),
                (route) => false,
              );
            }
          });
        }
      }
    } else {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();

    WidgetsBinding.instance.removeObserver(this);

    // Tüm stream subscriptionları temizle
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    super.dispose();
  }

  // Katılımcı listesini güncelleyen yardımcı metod
  void _updateParticipantsList(List<RoomParticipant> newParticipants) {
    if (!mounted) return;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- Notifier Dinleme ve Navigasyon ---
    ref.listen<RaceState>(raceNotifierProvider,
        (RaceState? previous, RaceState next) {
      // Skip if already navigating
      if (_navigationTriggered) return;

      // --- LOG RaceState DEĞİŞİMİ ---

      // --- LOG SONU ---

      // Check if the race has started (either countdown or actual race)
      if ((next.isPreRaceCountdownActive || next.isRaceActive) &&
          next.roomId != null &&
          next.roomId == widget.roomId) {
        // iOS cihazlar için ön konum etkinleştirme
        if (Platform.isIOS) {
          _enableIOSLocationForRace();
        }

        // --- NAVİGASYON Mantığı ---
        if (!_navigationTriggered) {
          _navigationTriggered = true;

          // --- KÜÇÜK BİR GECİKME EKLE ---
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              // Gecikme sonrası tekrar kontrol et
              WakelockPlus.disable();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => RaceScreen(
                    roomId: next.roomId!,
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
    // final String displayActivityType = widget.activityType ?? 'Bilinmiyor'; // OLD WAY

    // --- YENİ: Yarış tipini tersine çevirerek göster ---
    final String rawActivityType =
        widget.activityType?.toLowerCase() ?? 'bilinmiyor';
    final String displayActivityType;

    if (rawActivityType == 'outdoor') {
      displayActivityType = 'Dış Mekan';
    } else if (rawActivityType == 'indoor' || rawActivityType == 'iç mekan') {
      displayActivityType = 'İç Mekan';
    } else {
      displayActivityType = widget.activityType ??
          'Bilinmiyor'; // Fallback to original or default
    }
    // --- YENİ SONU ---

    // Use widget.duration directly, provide default if null
    // --- DEĞİŞİKLİK: Planlanan süreyi önceliklendir ---
    final String displayDuration;
    if (widget.duration != null) {
      displayDuration = '${widget.duration} dakika';
    } else {
      displayDuration = 'Belirsiz';
    }

    // --- Subtitle Text'i _isRaceStarting ve Notifier State'ine Göre Al (Güncellendi) ---
    final String subtitleText;
    const int maxParticipantsForNormalRace =
        3; // Max participants for normal matchmaking

    if (raceState.isPreRaceCountdownActive) {
      subtitleText = 'Yarış Başlıyor...';
    } else if (raceState.isRaceActive && !raceState.isPreRaceCountdownActive) {
      subtitleText = 'Yarış Başladı';
    } else {
      if (widget.roomCode.isEmpty && mounted) {
        // Normal matchmaking race and widget is mounted
        subtitleText =
            '${_participants.length}/$maxParticipantsForNormalRace Katılımcı';
      } else {
        // Private room or other cases
        subtitleText = 'Diğer yarışmacılar bekleniyor...';
      }
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
          // **** STACK İLE SAR ****
          child: Stack(
            children: [
              // **** MEVCUT İÇERİK (COLUMN) ****
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // Stretch elements horizontally
                  children: [
                    // Title
                    FontWidget(
                      text: 'Yarış Başlamak Üzere',
                      styleType: TextStyleType.titleLarge,
                      textAlign: TextAlign.center,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor,
                    ),
                    const SizedBox(height: 8),
                    // Subtitle (Güncellenmiş Metinle)
                    FontWidget(
                      text: subtitleText,
                      styleType: TextStyleType
                          .labelLarge, // Adjusted for Bangers style
                      textAlign: TextAlign.center,
                      fontSize: 16,
                      color: _accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                    const SizedBox(height: 30),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FontWidget(
                            text: 'Seçilen Yarış Tipi',
                            styleType: TextStyleType
                                .labelMedium, // Adjusted for Bangers style
                            fontSize: 14,
                            color: _secondaryTextColor,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/icons/bayrak.png',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: 8),
                              FontWidget(
                                text: displayActivityType,
                                styleType: TextStyleType
                                    .titleMedium, // Adjusted for Bangers style
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: _primaryTextColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FontWidget(
                            text: 'Yarış Süresi',
                            styleType: TextStyleType
                                .labelMedium, // Adjusted for Bangers style
                            fontSize: 14,
                            color: _secondaryTextColor,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/icons/time.png',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: 8),
                              FontWidget(
                                text: displayDuration,
                                styleType: TextStyleType
                                    .titleSmall, // Adjusted for Bangers style
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: _primaryTextColor,
                              ),
                            ],
                          ),
                          // Display Room Code
                          if (widget.roomCode.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            FontWidget(
                              text: 'Oda Kodu',
                              styleType: TextStyleType
                                  .labelMedium, // Adjusted for Bangers style
                              fontSize: 14,
                              color: _secondaryTextColor,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.meeting_room_outlined,
                                  color: _accentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    widget.roomCode,
                                    style: const TextStyle(
                                      // Keep SelectableText with TextStyle for now
                                      fontFamily:
                                          'Bangers', // Explicitly keep Bangers for SelectableText if needed
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _primaryTextColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: _accentColor, size: 20),
                                  tooltip: 'Kodu Kopyala',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: widget.roomCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: FontWidget(
                                              text: 'Oda kodu kopyalandı!',
                                              styleType: TextStyleType
                                                  .labelMedium)), // Adjusted for Bangers style
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share,
                                      color: _accentColor, size: 20),
                                  tooltip: 'Kodu Paylaş',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Share.share(' ${widget.roomCode}');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Central Image - Wrapped with AspectRatio and FittedBox
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0), // Padding for image
                        child: FittedBox(
                          fit: BoxFit
                              .contain, // Ensures the image is fully visible within the bounds
                          child: Image.asset(
                            'assets/images/waitingroom2.png', // Use provided asset
                            // Removed fixed height and width to allow FittedBox to manage sizing
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 20), // Adjusted SizedBox height after the image

                    // Participants Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 16.0),
                      decoration: BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FontWidget(
                            text: 'Hazır Olan Yarışmacılar',
                            styleType: TextStyleType
                                .labelLarge, // Adjusted for Bangers style
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _primaryTextColor,
                          ),
                          const SizedBox(height: 12),
                          // Stacked Profile Pictures
                          _buildParticipantAvatars(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Start Race Button (Conditional)
                    if (widget.isHost && _participants.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 10.0), // Add some space below
                        child: Center(
                          child: _isLoadingStartRace
                              ? const CircularProgressIndicator(
                                  color: _accentColor)
                              : ElevatedButton.icon(
                                  onPressed: _startRaceButtonPressed,
                                  label: FontWidget(
                                    text: 'Yarışı Başlat',
                                    styleType: TextStyleType
                                        .labelLarge, // Adjusted for Bangers style
                                    color: Colors
                                        .black, // Text color black for contrast
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _accentColor, // Button background
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                    // Leave Button
                    if (!_isLoading) // Hide button while loading/leaving
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _leaveRoom(showConfirmation: true),
                          icon: const Icon(Icons.exit_to_app,
                              color: _accentColor),
                          label: FontWidget(
                            text: 'Yarıştan Çık',
                            styleType: TextStyleType
                                .labelLarge, // Adjusted for Bangers style
                            color: _accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                            child:
                                CircularProgressIndicator(color: _accentColor)),
                      ),
                  ],
                ),
              ),

              // **** KOŞULLU GERİ SAYIM OVERLAY'İ ****
              if (/*!_isWaitingForPendingStart &&*/ raceState
                  .isPreRaceCountdownActive)
                Container(
                  color:
                      Colors.black.withOpacity(0.85), // Opaklık ayarlanabilir
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FontWidget(
                          text: 'Yarış Başlıyor',
                          styleType: TextStyleType
                              .titleMedium, // Adjusted for Bangers style
                          fontSize: 28, // Boyut RaceScreen ile aynı olabilir
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(height: 25),
                        FontWidget(
                          text: raceState.preRaceCountdownValue.toString(),
                          styleType: TextStyleType
                              .titleLarge, // Adjusted for Bangers style
                          fontSize: 120, // Boyut RaceScreen ile aynı olabilir
                          color: _accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // **** STACK SONU ****
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
            child: FontWidget(
              text: '+${_participants.length - maxVisibleAvatars}',
              styleType: TextStyleType.labelSmall, // Adjusted for Bangers style
              color: _backgroundColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
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

  void _enableIOSLocationForRace() {
    if (!Platform.isIOS) return;

    try {
      // Method channel aracılığıyla iOS native konum takibini etkinleştir
      const platform = MethodChannel('com.movliq/location');
      platform
          .invokeMethod('enableBackgroundLocationTracking')
          .then((_) {})
          .catchError((error) {});

      // Konum takibi için daha kapsamlı ısınma - birkaç kez konum alalım
      _aggressiveLocationWarmup();
    } catch (e) {}
  }

  void _warmupLocationServices() {
    if (!Platform.isIOS) return;

    try {
      // Servis durumunu kontrol et
      Geolocator.isLocationServiceEnabled().then((enabled) {
        if (!enabled) {
          return;
        }

        // İzinleri kontrol et
        Geolocator.checkPermission().then((permission) {
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            return;
          }

          // Location warmup - servisleri başlatmak için tek bir istek yap
          Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.best,
                  timeLimit: const Duration(seconds: 2))
              .then((position) {})
              .catchError((e) {
            // Zaman aşımı olabilir, sorun değil - servisler başlatılmış olur
          });
        });
      });
    } catch (e) {}
  }

  // Daha agresif konum ısındırma yaklaşımı - birkaç kez konum almayı dene
  void _aggressiveLocationWarmup() {
    if (!Platform.isIOS) return;

    // İlk ısındırma
    _warmupLocationServices();

    // Kısa bir süre sonra tekrar dene
    Future.delayed(const Duration(milliseconds: 500), () {
      _warmupLocationServices();

      // Bir 1 saniye sonra tekrar konumu al ve sürekli izleme başlat
      Future.delayed(const Duration(seconds: 1), () {
        _startContinuousLocationUpdates();
      });
    });

    // Biraz daha sonra tekrar ısındırma
    Future.delayed(const Duration(seconds: 2), () {
      _warmupLocationServices();
    });
  }

  // Sürekli konum güncellemesi - GPS'i sürekli açık tutmak için
  void _startContinuousLocationUpdates() {
    if (!Platform.isIOS) return;

    try {
      LocationSettings locationSettings = AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true);

      // Kısa bir stream başlat, hemen iptal edilecek ama iOS'un konum servisini başlatmasını sağlayacak
      var tempSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((position) {});

      // 10 saniye sonra bu stream'i kapat - bu süre içinde RaceScreen'e geçilmiş olmalı
      Future.delayed(const Duration(seconds: 10), () {
        tempSubscription.cancel();
      });
    } catch (e) {}
  }

  // Method to handle "Start Race" button press
  Future<void> _startRaceButtonPressed() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStartRace = true;
    });

    try {
      // Token is handled by HttpInterceptor, no need to fetch manually here
      // final token = await StorageService.getToken();
      // if (token == null) {
      //   _showErrorMessage('Kimlik doğrulama başarısız.');
      //   setState(() => _isLoadingStartRace = false);
      //   return;
      // }

      final String url =
          '${ApiConfig.startCreatedRoomEndpoint}/${widget.roomId}'; // Construct URL with roomId as path parameter

      final response = await HttpInterceptor.post(
        Uri.parse(url),
        body: jsonEncode({}), // Send an empty JSON object as the body
      );

      if (response.statusCode == 200) {
        // Success, SignalR should handle navigation via raceStartingStream
        // Optionally, show a success message, though it might be quick if navigation is fast
        // _showInfoMessage('Yarış başlatma komutu gönderildi.');
        // The raceNotifier and SignalR stream should now trigger navigation to RaceScreen
      } else {
        final responseData = jsonDecode(response.body);
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStartRace = false;
        });
      }
    }
  }

  // --- App Lifecycle State Değişikliği ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Bağlantıyı ve odaya katılımı yeniden kurmayı dene
      // _setupSignalR'ı direkt çağırmak yerine, bağlantı durumunu kontrol edip
      // sadece gerekliyse yeniden bağlanmak daha iyi olabilir.
      // Ancak _setupSignalR zaten bağlantı varsa fazla işlem yapmıyor gibi duruyor.
      // Şimdilik _setupSignalR'ı tekrar çağıralım,
      // ileride daha sofistike bir kontrol eklenebilir.
      final signalRService = ref.read(signalRServiceProvider);
      if (!signalRService.isConnected) {
        _setupSignalR().then((_) {
          if (_isConnected) {
            // Odaya yeniden katılımı sağlamak için joinRaceRoom çağrılabilir
            // _setupSignalR içinde bu zaten yapılıyor olabilir, kontrol etmek gerek.
            // Eğer _setupSignalR içinde joinRaceRoom çağrılmıyorsa veya
            // tekrar çağırmak gerekiyorsa:
            // ref.read(signalRServiceProvider).joinRaceRoom(widget.roomId);
          } else {}
        });
      } else {
        // Bağlantı aktifse bile, odaya katılımı teyit etmek iyi bir pratik olabilir.
        // Özellikle ağ kesintisi sonrası 'resumed' durumunda.
        // signalRService.joinRaceRoom(widget.roomId); // Opsiyonel: Odaya katılımı teyit et
      }
    } else if (state == AppLifecycleState.paused) {
      // Arka plana alındığında özel bir işlem yapmak isterseniz buraya ekleyebilirsiniz.
      // Örneğin, bazı dinleyicileri geçici olarak durdurmak vs.
      // Ancak SignalR genellikle sunucu tarafı timeout'larla yönetilir.
    }
  }
}
