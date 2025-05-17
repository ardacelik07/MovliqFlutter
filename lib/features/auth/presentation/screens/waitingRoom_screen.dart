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
  List<RoomParticipant> _participants = [];
  String? _myUsername; // Kullanıcı adı
  String? _myEmail; // Email adresi
  String? _lastJoinedUser;
  bool _isLoading = false; // Son katılan kullanıcı

  // Fotoğraf önbelleği için harita ekliyoruz
  final Map<String, String?> _profilePictureCache = {};

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  // Listen for race state changes to detect race starting
  bool _navigationTriggered = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _hasStartTime = widget.startTime != null;
    _participants = []; // Boş liste ile başlat
    debugPrint('🔄 WaitingRoom initState - Başlangıç durumu:');
    debugPrint('🏠 Oda ID: ${widget.roomId}');

    // Kullanıcı adını al
    _loadUsername().then((_) {
      _storeBeforeRaceCoin();
    });

    // SignalR bağlantısını başlat
    _setupSignalR().then((_) {
      // SignalR bağlantısı kurulduktan sonra ilk katılımcı listesini al
      if (_isConnected) {
        debugPrint('📥 İlk katılımcı listesi alınıyor...');
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
      print(
          "🏁 RaceCoinTracker: Yarış öncesi coin alınamadı (userData null veya coin null).");
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
        if (!mounted) return;

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
        if (!mounted) return;

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

      // Yarış başlama olayını dinle (Bu artık RaceAlreadyStarted olarak düşünülmeli)
      _subscriptions.add(signalRService.raceStartingStream.listen((data) {
        debugPrint(
            '--- WaitingRoom: RaceStarting (or RaceAlreadyStarted) event RECEIVED --- Data: $data');

        if (!mounted) {
          debugPrint(
              '--- WaitingRoom: RaceStarting - Widget not mounted, skipping. --- ');
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
          debugPrint(
              '--- WaitingRoom: HATA - Kullanıcı email bilgisi null! Yarış başlatılamıyor. ---');
          _showErrorMessage(
              'Kullanıcı bilgileri yüklenemediği için yarış başlatılamadı.');
          return;
        }

        if (roomId == widget.roomId) {
          if (isRaceReallyAlreadyStarted) {
            // --- DEVAM EDEN YARIŞA KATILMA SENARYOSU ---
            final double? remainingTimeForOngoingRace =
                data['remainingTimeSeconds'] as double?;
            if (remainingTimeForOngoingRace != null) {
              debugPrint(
                  '--- WaitingRoom: Event is for ONGOING race. Room ID: $roomId, RemainingTime: $remainingTimeForOngoingRace ---');
              debugPrint(
                  '--- WaitingRoom: >>> Calling raceNotifier.startRace for ONGOING race... ---');
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
              debugPrint(
                  '--- WaitingRoom: raceNotifier.startRace CALLED for ONGOING race. ---');
            } else {
              debugPrint(
                  '--- WaitingRoom: RaceAlreadyStarted event BUT remainingTimeForOngoingRace is NULL. Data: $data ---');
            }
          } else {
            // --- NORMAL YARIŞ BAŞLANGICI SENARYOSU ---
            final int countdownSeconds = data['countdownSeconds'] ?? 10;
            debugPrint(
                '--- WaitingRoom: Event is for NEW race starting. Room ID: $roomId, Countdown: $countdownSeconds ---');
            debugPrint(
                '--- WaitingRoom: >>> Calling raceNotifier.startRace for NEW race... ---');
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
            debugPrint(
                '--- WaitingRoom: raceNotifier.startRace CALLED for NEW race. ---');
          }
        } else {
          debugPrint(
              '--- WaitingRoom: RaceStarting/RaceAlreadyStarted event for a DIFFERENT room ID. Current: ${widget.roomId}, Event: $roomId. Data: $data ---');
        }
      }));

      // --- YENİ: Yeniden Bağlanma Olayını Dinle ---
      _subscriptions.add(
          signalRService.reconnectedStream.listen((String? newConnectionId) {
        if (newConnectionId != null && mounted) {
          debugPrint(
              '🔄 WaitingRoom: SignalR yeniden bağlandı. Yeni Bağlantı ID: $newConnectionId');
          debugPrint(
              '🚪 Odaya (${widget.roomId}) yeniden katılım sağlanıyor...');
          try {
            signalRService.joinRaceRoom(widget.roomId).then((_) {
              debugPrint(
                  '✅ WaitingRoom: Odaya (${widget.roomId}) yeniden katılım isteği gönderildi.');
              // Katılımcı listesini yenilemek için bir flag veya metod çağrısı eklenebilir.
              // Şimdilik joinRaceRoom'un sunucudan RoomParticipants göndermesini bekliyoruz.
            }).catchError((e) {
              debugPrint('❌ WaitingRoom: Odaya yeniden katılırken hata: $e');
              _showErrorMessage(
                  'Yeniden bağlanma sonrası odaya katılım başarısız oldu.');
            });
          } catch (e) {
            debugPrint(
                '❌ WaitingRoom: signalRService.joinRaceRoom çağrılırken hata: $e');
            _showErrorMessage(
                'Yeniden bağlanma sonrası odaya katılım sırasında bir hata oluştu.');
          }
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
        WakelockPlus.disable();
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
    if (!mounted) {
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

    if (mounted) {
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
        (RaceState? previous, RaceState next) {
      // Skip if already navigating
      if (_navigationTriggered) return;

      // --- LOG RaceState DEĞİŞİMİ ---
      debugPrint('--- WaitingRoom RaceState Listener ---');
      debugPrint('isPreRaceCountdownActive: ${next.isPreRaceCountdownActive}');
      debugPrint('isRaceActive: ${next.isRaceActive}');
      debugPrint('roomId: ${next.roomId}');
      // --- LOG SONU ---

      // Check if the race has started (either countdown or actual race)
      if ((next.isPreRaceCountdownActive || next.isRaceActive) &&
          next.roomId != null &&
          next.roomId == widget.roomId) {
        // iOS cihazlar için ön konum etkinleştirme
        if (Platform.isIOS) {
          debugPrint(
              '--- WaitingRoom: iOS için ön konum etkinleştirme yapılıyor... ---');
          _enableIOSLocationForRace();
        }

        // --- NAVİGASYON Mantığı ---
        if (!_navigationTriggered) {
          _navigationTriggered = true;
          debugPrint(
              '--- WaitingRoom: RaceNotifier reported race started. Navigating to RaceScreen... ---');

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
    final String displayActivityType = widget.activityType ?? 'Bilinmiyor';
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
    if (raceState.isPreRaceCountdownActive) {
      subtitleText = 'Yarış Başlıyor...';
    } else if (raceState.isRaceActive && !raceState.isPreRaceCountdownActive) {
      subtitleText = 'Yarış Başladı';
    } else {
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
                    // Subtitle (Güncellenmiş Metinle)
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
                          icon: const Icon(Icons.exit_to_app,
                              color: _accentColor),
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
                        const Text(
                          'Yarış Başlıyor',
                          style: TextStyle(
                            fontSize: 28, // Boyut RaceScreen ile aynı olabilir
                            color: _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          raceState.preRaceCountdownValue.toString(),
                          style: const TextStyle(
                              fontSize:
                                  120, // Boyut RaceScreen ile aynı olabilir
                              color: _accentColor,
                              fontWeight: FontWeight.bold),
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

  void _enableIOSLocationForRace() {
    if (!Platform.isIOS) return;

    try {
      debugPrint(
          'WaitingRoom: iOS arka plan konum takibi etkinleştiriliyor...');

      // Method channel aracılığıyla iOS native konum takibini etkinleştir
      const platform = MethodChannel('com.movliq/location');
      platform.invokeMethod('enableBackgroundLocationTracking').then((_) {
        debugPrint(
            'WaitingRoom: iOS native konum takibi başarıyla etkinleştirildi.');
      }).catchError((error) {
        debugPrint(
            'WaitingRoom: iOS native konum takibi etkinleştirme hatası: $error');
      });

      // Konum takibi için daha kapsamlı ısınma - birkaç kez konum alalım
      _aggressiveLocationWarmup();
    } catch (e) {
      debugPrint('WaitingRoom: iOS konum takibi genel hatası: $e');
    }
  }

  void _warmupLocationServices() {
    if (!Platform.isIOS) return;

    try {
      // Servis durumunu kontrol et
      Geolocator.isLocationServiceEnabled().then((enabled) {
        if (!enabled) {
          debugPrint('WaitingRoom: Konum servisleri kapalı!');
          return;
        }

        // İzinleri kontrol et
        Geolocator.checkPermission().then((permission) {
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            debugPrint('WaitingRoom: Konum izinleri reddedilmiş!');
            return;
          }

          // Location warmup - servisleri başlatmak için tek bir istek yap
          debugPrint('WaitingRoom: Konum servislerini ısındırma...');
          Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.best,
                  timeLimit: const Duration(seconds: 2))
              .then((position) {
            debugPrint(
                'WaitingRoom: Konum alındı: ${position.latitude}, ${position.longitude}');
          }).catchError((e) {
            // Zaman aşımı olabilir, sorun değil - servisler başlatılmış olur
            debugPrint('WaitingRoom: Konum ısındırma hatası: $e');
          });
        });
      });
    } catch (e) {
      debugPrint('WaitingRoom: Konum ısındırma genel hatası: $e');
    }
  }

  // Daha agresif konum ısındırma yaklaşımı - birkaç kez konum almayı dene
  void _aggressiveLocationWarmup() {
    if (!Platform.isIOS) return;

    debugPrint('WaitingRoom: Agresif konum ısındırma başlatılıyor...');

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

    debugPrint('WaitingRoom: Sürekli konum güncellemesi başlatılıyor...');

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
              .listen((position) {
        debugPrint(
            'WaitingRoom: Sürekli konum - Position update: ${position.latitude}, ${position.longitude}');
      });

      // 10 saniye sonra bu stream'i kapat - bu süre içinde RaceScreen'e geçilmiş olmalı
      Future.delayed(const Duration(seconds: 10), () {
        tempSubscription.cancel();
        debugPrint('WaitingRoom: Geçici konum stream iptal edildi');
      });
    } catch (e) {
      debugPrint('WaitingRoom: Sürekli konum başlatma hatası: $e');
    }
  }
}
