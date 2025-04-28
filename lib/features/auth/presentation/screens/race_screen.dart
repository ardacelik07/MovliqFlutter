import 'dart:async';
import 'dart:convert';
import 'dart:convert' show jsonDecode;
import 'dart:convert' show utf8;
import 'dart:convert' show base64Url;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/signalr_service.dart';
import '../screens/tabs.dart';
import '../../../../core/services/storage_service.dart';
import 'finish_race_screen.dart';
import '../widgets/user_profile_avatar.dart';

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? myUsername;
  final int? raceDuration; // Minutes
  final Map<String, String?> profilePictureCache; // Cache parametresini ekledik
  final bool isIndoorRace; // Indoor yarış tipini belirlemek için yeni parametre

  const RaceScreen({
    super.key,
    required this.roomId,
    this.myUsername,
    this.raceDuration,
    required this.profilePictureCache,
    required this.isIndoorRace, // Constructor'a ekledik
  });

  @override
  ConsumerState<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends ConsumerState<RaceScreen> {
  List<RaceParticipant> _leaderboard = [];
  bool _isConnected = false;
  bool _isRaceActive = true;
  double _myDistance = 0.0;
  int _mySteps = 0;
  String? _myEmail;
  Timer? _locationUpdateTimer;
  Timer? _raceTimerTimer;
  Timer? _antiCheatTimer; // Anti-cheat timer ekledik
  Duration _remainingRaceTime =
      const Duration(minutes: 10); // Default to 10 minutes
  bool _isTimerInitialized = false;

  // Hile kontrolü için gerekli değişkenler
  double _lastCheckDistance = 0.0;
  int _lastCheckSteps = 0;
  DateTime? _lastCheckTime;
  int _violationCount = 0; // İhlal sayısını takip etmek için eklendi

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  // Konum takibi için gerekli özellikler
  Position? _currentPosition;
  Position?
      _previousPosition; // Bu değişkeni kullanmayacağız, RecordScreen'deki gibi
  bool _hasLocationPermission = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Adım sayar için gerekli özellikler
  int _initialSteps = 0;
  bool _hasPedometerPermission = false;
  StreamSubscription<StepCount>? _stepCountSubscription;

  @override
  void initState() {
    super.initState();

    // Bildirimleri temizleyen kodu kaldırıyorum
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).clearSnackBars();
    //   }
    // });

    _setupSignalR();
    _initPermissions(); // Konum ve adım izinlerini başlat
    _initializeRaceTimer();
    _initializeAntiCheatSystem(); // Hile kontrol sistemini başlat
  }

  // Tüm izinleri başlatan fonksiyon
  Future<void> _initPermissions() async {
    // Indoor yarış ise sadece adım sayar izni al, GPS izni alma
    if (widget.isIndoorRace) {
      await _checkActivityPermission();
      return;
    }

    // Outdoor yarış: konum servislerinin açık olup olmadığını kontrol et
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Konum servisleri kapalıysa, kullanıcıyı uyar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen konum servislerini açın'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Konum servislerini açma isteği göster
      await Geolocator.openLocationSettings();
      return;
    }

    await _checkLocationPermission();
    await _checkActivityPermission();
  }

  // Aktivite izinlerini kontrol eden fonksiyon
  Future<void> _checkActivityPermission() async {
    // Platform-specific permission checks
    if (Platform.isAndroid) {
      // Android'de adım sayar iznini kontrol et
      if (await Permission.activityRecognition.request().isGranted) {
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    } else if (Platform.isIOS) {
      // iOS'ta motion sensörü izni için
      if (await Permission.sensors.request().isGranted) {
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    }
  }

  // Konum izinlerini kontrol eden fonksiyon
  Future<void> _checkLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final LocationPermission requestedPermission =
            await Geolocator.requestPermission();

        setState(() {
          _hasLocationPermission =
              requestedPermission != LocationPermission.denied &&
                  requestedPermission != LocationPermission.deniedForever;
        });
      } else {
        setState(() {
          _hasLocationPermission = permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever;
        });
      }

      debugPrint('Konum izin durumu: $_hasLocationPermission');

      if (_hasLocationPermission) {
        // İzin varsa ilk konumu al
        await _getCurrentLocation();
        // Eğer yarış aktifse konum takibini başlat
        if (_isRaceActive) {
          _startLocationUpdates();
        }
      }
    } catch (e) {
      debugPrint('Konum izni hatası: $e');
    }
  }

  // Mevcut konumu alan fonksiyon
  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('Konum alınıyor...');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high); // RecordScreen ile aynı

      debugPrint('Konum alındı: ${position.latitude}, ${position.longitude}');

      setState(() {
        // Sadece mevcut konumu ayarla, RecordScreen gibi
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
    }
  }

  void _initializeRaceTimer() {
    // Use the race duration from the widget, or default to 10 minutes
    final raceDurationMinutes = widget.raceDuration ?? 10;

    setState(() {
      _remainingRaceTime = Duration(minutes: raceDurationMinutes);
      _isTimerInitialized = true;
    });

    _raceTimerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingRaceTime.inSeconds > 0) {
        setState(() {
          _remainingRaceTime = _remainingRaceTime - const Duration(seconds: 1);
        });
      } else {
        // Race time is over, but we'll wait for the server to tell us it's over
        timer.cancel();
        _raceTimerTimer = null;

        // If the server hasn't already told us the race is over, we'll show a message
        if (_isRaceActive) {
          debugPrint('Race timer ended, waiting for server confirmation...');
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _setupSignalR() async {
    final signalRService = ref.read(signalRServiceProvider);

    try {
      // SignalR bağlantısını başlat ve odaya katıl
      await signalRService.connect();
      await signalRService.joinRaceRoom(widget.roomId);

      setState(() {
        _isConnected = signalRService.isConnected;
      });

      // Liderlik tablosu güncellemelerini dinle
      _subscriptions.add(signalRService.leaderboardStream.listen((leaderboard) {
        if (!mounted) return;

        setState(() {
          _leaderboard = leaderboard;

          // Kendi email'imi al ve konumumu güncelle
          if (_myEmail == null &&
              leaderboard.isNotEmpty &&
              widget.myUsername != null) {
            // Kullanıcı adı bilgisini kullanarak kendimizi tanıyalım
            final me = leaderboard.firstWhere(
              (p) =>
                  p.userName.toLowerCase() == widget.myUsername!.toLowerCase(),
              orElse: () {
                debugPrint(
                    'Kullanıcı "${widget.myUsername}" leaderboard içinde bulunamadı, ilk kullanıcı seçiliyor.');
                return leaderboard.first;
              },
            );
            _myEmail = me.email;
            debugPrint('Kullanıcı bulundu: ${me.userName} (${me.email})');
          }
        });
      }));

      // Konum güncellemelerini dinle
      _subscriptions.add(signalRService.locationUpdatedStream.listen((data) {
        if (!mounted) return;

        debugPrint(
            'Konum güncellendi: ${data['email']}, ${data['distance']} m, ${data['steps']} adım');
      }));

      // Kullanıcı katılma olayını dinle ama bildirim gösterme
      _subscriptions.add(signalRService.userJoinedStream.listen((username) {
        if (!mounted) return;
        // Sadece log yazdıralım, bildirim göstermeyelim
        debugPrint(
            'Kullanıcı yarışa katıldı (bildirim gösterilmedi): $username');
      }));

      // Kullanıcı ayrılma olayını dinle
      _subscriptions.add(signalRService.userLeftStream.listen((username) {
        if (!mounted) return;
        _showInfoMessage('$username odadan ayrıldı');
      }));

      // Yarış sona erdiğinde
      _subscriptions.add(signalRService.raceEndedStream.listen((roomId) {
        if (!mounted) return;

        debugPrint('RaceScreen: Yarış sona erdi olayı alındı! Oda ID: $roomId');

        // Eğer kendi odamızın ID'si ile eşleşiyorsa veya genel bir bildirimse (0)
        if (roomId == widget.roomId || roomId == 0) {
          debugPrint(
              'RaceScreen: Bu odanın yarışı sona erdi, sonuç ekranı gösteriliyor');

          setState(() {
            _isRaceActive = false;
          });

          _showRaceEndedMessage();
          _stopLocationUpdates();
        }
      }));
    } catch (e) {
      _showErrorMessage('SignalR bağlantı hatası: $e');
    }
  }

  // Adım sayar başlatma fonksiyonu
  void _initPedometer() {
    _stepCountSubscription =
        Pedometer.stepCountStream.listen((StepCount event) {
      if (!mounted) return;

      setState(() {
        if (_isRaceActive && _initialSteps == 0) {
          _initialSteps = event.steps;
          _mySteps = 0;
          debugPrint('Başlangıç adım sayısı ayarlandı: $_initialSteps');
        } else if (_isRaceActive) {
          int newSteps = event.steps - _initialSteps;
          // Adım sayısı azalmadıysa güncelle (mantık hatası kontrolü)
          if (newSteps >= _mySteps) {
            _mySteps = newSteps;
            debugPrint('Adım sayısı güncellendi: $_mySteps');

            // Adım güncellemesini sunucuya gönder
            _updateLocation();
          }
        }
      });
    }, onError: (error) {
      debugPrint('Adım sayar hatası: $error');
    });
  }

  void _startLocationUpdates() {
    // Indoor yarış ise konum takibini kesinlikle engelle
    if (widget.isIndoorRace) {
      debugPrint('🚫 Indoor yarış - GPS konum takibi tamamen devre dışı');
      // Eğer bir şekilde başlatılmış olan konum takibi varsa durdur
      _stopLocationUpdates();
      return;
    }

    // Bundan sonraki kod sadece outdoor yarışlarda çalışacak
    if (!_hasLocationPermission) {
      _checkLocationPermission();
      return;
    }

    // Normal konum takibi kodu...
    try {
      debugPrint('Konum takibi başlatılıyor...');

      // RecordScreen ile tamamen aynı:
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // RecordScreen ile birebir aynı
        ),
      ).listen((Position position) {
        if (!mounted || !_isRaceActive) return;

        debugPrint(
            'Konum güncellendi: ${position.latitude}, ${position.longitude}');

        setState(() {
          // Indoor yarış değilse mesafe hesapla
          if (!widget.isIndoorRace && _currentPosition != null) {
            double newDistance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            _myDistance += newDistance / 1000;
            debugPrint(
                'Mesafe eklendi: ${newDistance / 1000} km. Toplam: $_myDistance km');
          }

          _currentPosition = position;

          // Konum güncellemesi gönder
          _updateLocation();
        });
      }, onError: (e) {
        debugPrint('Konum takibi hatası: $e');
      });
    } catch (e) {
      debugPrint('Konum takibi başlatma hatası: $e');
    }
  }

  void _stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<void> _updateLocation() async {
    if (!_isConnected || !_isRaceActive) return;

    try {
      double distanceToSend = 0.0; // Varsayılan değer her zaman 0

      // Sadece outdoor yarışlarda gerçek mesafe değerini gönder
      if (!widget.isIndoorRace) {
        distanceToSend = _myDistance;
      } else {
        // Indoor yarışta mesafe değerini zorla 0 yap ve değişkeni de sıfırla
        _myDistance = 0.0;
      }

      debugPrint(
          '📊 Sunucuya gönderilen mesafe: $distanceToSend km (Indoor: ${widget.isIndoorRace})');

      await ref
          .read(signalRServiceProvider)
          .updateLocation(widget.roomId, distanceToSend, _mySteps);
    } catch (e) {
      debugPrint('❌ Konum güncellemesi gönderilirken hata: $e');
    }
  }

  void _showRaceEndedMessage() {
    debugPrint('RaceScreen: _showRaceEndedMessage() çağrıldı');

    if (!mounted) return;

    // Popup yerine yeni ekrana yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FinishRaceScreen(
          leaderboard: _leaderboard,
          myEmail: _myEmail,
          isIndoorRace: widget.isIndoorRace, // Indoor yarış parametresini geçir
          profilePictureCache: Map<String, String?>.from(
              widget.profilePictureCache), // Use widget.profilePictureCache
        ),
      ),
    );
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Hile kontrol sistemini başlatan fonksiyon
  void _initializeAntiCheatSystem() {
    // İndoor yarışlarda hile kontrolü yapma (mesafe takibi olmadığı için)
    if (widget.isIndoorRace) {
      debugPrint('Indoor yarış - Hile kontrolü devre dışı');
      return;
    }

    // İlk kontrol için başlangıç değerlerini kaydet
    _lastCheckDistance = _myDistance;
    _lastCheckSteps = _mySteps;
    _lastCheckTime = DateTime.now();

    // Her 30 saniyede bir hile kontrolü yap
    _antiCheatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted || !_isRaceActive) {
        timer.cancel();
        return;
      }

      _checkForCheating();
    });
  }

  // Hile kontrolü yapan fonksiyon
  void _checkForCheating() {
    // Eğer ilk kontrolse veya yarış aktif değilse kontrol yapma
    if (_lastCheckTime == null || !_isRaceActive) return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastCheckTime!).inSeconds;

    // 30 saniye geçmediyse kontrol yapma (Timer hassasiyeti için ek kontrol)
    if (elapsedSeconds < 25) return;

    final currentDistance = _myDistance;
    final currentSteps = _mySteps;

    // Son kontrolden bu yana kat edilen mesafe (km'den metreye çevir)
    final distanceDifference = (currentDistance - _lastCheckDistance) * 1000;
    final stepsDifference = currentSteps - _lastCheckSteps;

    debugPrint(
        '🔍 Hile kontrol: $elapsedSeconds saniyede $distanceDifference metre, $stepsDifference adım');

    bool violation = false;
    String title = '';
    String message = '';

    // Hile kontrolü: 30 saniyede maksimum 250 metre
    if (distanceDifference > 250) {
      violation = true;
      title = 'Anormal hız tespit edildi';
      message =
          'Son 30 saniyede $distanceDifference metre mesafe kaydedildi. Maksimum limit 250 metredir.';
    }
    // Hile kontrolü: Her metre için minimum 0.5 adım
    else if (distanceDifference > 0) {
      final requiredMinSteps = distanceDifference * 0.5;
      if (stepsDifference < requiredMinSteps) {
        violation = true;
        title = 'Anormal adım-mesafe oranı tespit edildi';
        message =
            'Son 30 saniyede $distanceDifference metre için en az ${requiredMinSteps.toInt()} adım atılması gerekirken, $stepsDifference adım kaydedildi.';
      }
    }

    // İhlal tespit edildiyse işlem yap
    if (violation) {
      _violationCount++;
      debugPrint('❌ İhlal tespit edildi: $_violationCount. ihlal');

      if (_violationCount >= 2) {
        // İkinci ihlalde kullanıcıyı yarıştan at
        _showViolationLimitExceededDialog(title, message);
      } else {
        // İlk ihlalde sadece uyarı ver
        _showCheatWarningDialog(title, message);
      }
    }

    // Yeni kontrol için değerleri güncelle
    _lastCheckDistance = currentDistance;
    _lastCheckSteps = currentSteps;
    _lastCheckTime = now;
  }

  // Hile uyarı dialogu gösteren fonksiyon
  void _showCheatWarningDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Lütfen gerçek koşu hızınızla devam edin. Tekrarlanan ihlaller hesabınızın askıya alınmasına neden olabilir.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Anladım'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // İhlal limitinin aşıldığını gösteren dialog
  void _showViolationLimitExceededDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$title - Yarış Sonlandırılıyor',
            style: const TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'İhlal sayınız limiti aştığı için yarıştan çıkarılıyorsunuz.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Anladım'),
            onPressed: () {
              Navigator.of(context).pop();
              // Kullanıcıyı yarış odasından çıkar
              _leaveRaceRoom(wasKicked: true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Fiziksel geri tuşuna basıldığında doğrudan odadan ayrılma diyalogunu göster
        return await _showLeaveConfirmationDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E), // Dark background
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E), // Dark background
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back, color: Colors.white), // White icon
            onPressed: () {
              _showLeaveConfirmationDialog();
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                // Update title text
                'Yarış Odası',
                style: TextStyle(
                  fontSize: 18, // Adjusted size
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text
                ),
              ),
              Text(
                // Update subtitle text and style
                _isRaceActive ? 'Yarış devam ediyor' : 'Yarış bitti',
                style: TextStyle(
                  fontSize: 14, // Adjusted size
                  color: _isRaceActive
                      ? Colors.greenAccent
                      : Colors.redAccent, // Accent colors
                ),
              ),
            ],
          ),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.grey.shade700 // Darker grey for connected
                    : Colors.red.shade700, // Darker red for disconnected
                borderRadius: BorderRadius.circular(20), // More rounded
              ),
              child: Text(
                // Update button text and style
                _isConnected ? 'Bağlandı' : 'Bağlantı Kesildi',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        body: Container(
          // Remove gradient, use solid dark background
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF1E1E1E), // Dark background
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20), // Increased spacing
                // İlerleme bilgisi - Updated Stats Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 10), // Adjusted padding
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800, // Darker card color
                    borderRadius:
                        BorderRadius.circular(16), // More rounded corners
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.timer_outlined, // Use outlined icon
                        value: _isTimerInitialized
                            ? _formatDuration(_remainingRaceTime)
                            : '--:--', // Placeholder
                        label: 'Kalan Süre', // Turkish label
                        iconColor: Colors.redAccent, // Accent color
                        valueColor: _remainingRaceTime.inSeconds < 60
                            ? Colors.redAccent
                            : Colors.white, // White text
                      ),
                      if (!widget.isIndoorRace)
                        _buildStatItem(
                          icon: Icons
                              .directions_run_outlined, // Use outlined icon
                          value: _myDistance.toStringAsFixed(2),
                          label: 'Mesafe (km)', // Turkish label
                          iconColor: Colors.blueAccent, // Accent color
                          valueColor: Colors.white, // White text
                        ),
                      _buildStatItem(
                        icon:
                            Icons.directions_walk_outlined, // Use outlined icon
                        value: _mySteps.toString(),
                        label: 'Adım', // Turkish label
                        iconColor: Colors.greenAccent, // Accent color
                        valueColor: Colors.white, // White text
                      ),
                      if (!widget.isIndoorRace)
                        _buildStatItem(
                          icon: Icons.speed_outlined, // Use outlined icon
                          value: _mySteps > 0
                              ? (_myDistance / _mySteps).toStringAsFixed(
                                  2) // km per step - as per image label
                              : '0.0',
                          label: 'Hız (km/adım)', // Turkish label from image
                          iconColor: Colors.orangeAccent, // Accent color
                          valueColor: Colors.white, // White text
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 25), // Increased spacing
                // Leaderboard başlığı - Updated Title
                Padding(
                  // Use Padding for alignment
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 28), // Larger icon
                      const SizedBox(width: 8),
                      const Text(
                        'Yarış Sıralaması', // Turkish title
                        style: TextStyle(
                          fontSize: 20, // Adjusted size
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // White text
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15), // Adjusted spacing
                Expanded(
                  child: _leaderboard.isEmpty
                      ? const Center(
                          child: Text(
                            'Waiting for participants...',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _leaderboard.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final participant = _leaderboard[index];
                            final isMe = participant.email == _myEmail;

                            return ParticipantTile(
                              participant: participant,
                              isMe: isMe,
                              profilePictureUrl: widget.profilePictureCache[
                                  participant
                                      .userName], // Cache'den profil fotoğrafını al
                              isIndoorRace: widget
                                  .isIndoorRace, // Indoor yarış parametresini geçir
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor, // Added required iconColor
    Color? valueColor,
  }) {
    // Removed old color logic

    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
      children: [
        // Circular background for icon
        Container(
          padding: const EdgeInsets.all(12), // Increased padding
          decoration: BoxDecoration(
            color:
                iconColor.withOpacity(0.2), // Use provided color with opacity
            shape: BoxShape.circle, // Make it circular
          ),
          child: Icon(icon, size: 28, color: iconColor), // Use provided color
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20, // Increased size
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white, // Default to white
          ),
        ),
        const SizedBox(height: 4), // Added spacing
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey, // Lighter grey label
          ),
        ),
      ],
    );
  }

  // Kullanıcının yarış esnasında odadan ayrılmasını onaylatan dialog
  Future<bool> _showLeaveConfirmationDialog() async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yarıştan Ayrıl'),
        content: const Text(
            'Yarış devam ediyor. Ayrılmak istediğinize emin misiniz? İstatistikleriniz sıfırlanacak ve liderlik tablosundan çıkarılacaksınız.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Evet, Ayrıl'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _leaveRaceRoom();
      return true;
    }

    return false;
  }

  // Yarış esnasında odadan ayrılma işlemini yapan metod
  Future<void> _leaveRaceRoom({bool wasKicked = false}) async {
    try {
      // Konum güncellemelerini durdur
      _stopLocationUpdates();

      // Adım sayacı aboneliğini iptal et
      _stepCountSubscription?.cancel();

      // SignalR bağlantısını kur ve LeaveRoomDuringRace metodunu çağır
      final signalRService = ref.read(signalRServiceProvider);

      if (signalRService.isConnected) {
        // Yarış esnasında ayrılma özel metodunu çağır
        await signalRService.leaveRoomDuringRace(widget.roomId);
        debugPrint(
            'SignalR: Yarış esnasında odadan ayrılma başarılı - Oda ID: ${widget.roomId}');
      } else {
        debugPrint('SignalR bağlantısı yok, önce bağlantı kuruluyor...');
        await signalRService.connect();
        await signalRService.leaveRoomDuringRace(widget.roomId);
      }

      // Stream aboneliklerini iptal et
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();

      if (mounted) {
        // Eğer kullanıcı atıldıysa bir mesaj göster
        if (wasKicked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Kurallara uymadığınız için yarıştan çıkarıldınız.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }

        // Ana sayfaya yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TabsScreen()),
          (route) => false, // Tüm geçmiş sayfaları temizle
        );
      }
    } catch (e) {
      debugPrint('Yarış esnasında odadan ayrılma hatası: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Odadan ayrılırken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    debugPrint('RaceScreen dispose ediliyor...');

    // Anti-cheat timer'ı iptal et
    _antiCheatTimer?.cancel();
    _antiCheatTimer = null;

    // Konum takibini durdur
    _stopLocationUpdates();

    // Adım sayar aboneliğini iptal et
    _stepCountSubscription?.cancel();

    // Race timer'ı iptal et
    _raceTimerTimer?.cancel();
    _raceTimerTimer = null;

    // Stream aboneliklerini iptal et
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Yeni kod: dispose sırasında normal LeaveRaceRoom yerine normale dönüyoruz
    // böylece dispose edildiğinde ikinci kez _leaveRaceRoom çağrılmayacak
    final signalRService = ref.read(signalRServiceProvider);
    if (_isRaceActive) {
      // Eğer kullanıcı uygulama kapatma gibi bir yolla çıkış yaparsa yine de istatistikleri sıfırlanmalı
      try {
        if (signalRService.isConnected) {
          signalRService.leaveRoomDuringRace(widget.roomId);
        }
      } catch (e) {
        debugPrint('Dispose sırasında odadan ayrılma hatası: $e');
      }
    } else {
      signalRService.leaveRaceRoom(widget.roomId);
    }

    debugPrint('RaceScreen dispose edildi - tüm dinleyiciler kapatıldı');
    super.dispose();
  }
}

class ParticipantTile extends StatelessWidget {
  final RaceParticipant participant;
  final bool isMe;
  final String? profilePictureUrl;
  final bool isIndoorRace; // Indoor yarış tipini belirleyen parametre ekledik

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isMe = false,
    this.profilePictureUrl,
    required this.isIndoorRace, // Constructor'a ekledik
  });

  @override
  Widget build(BuildContext context) {
    // Sıralamaya göre renkleri belirle
    Color rankColor;
    Color rankTextColor = Colors.black87; // Default text color for rank badge
    if (participant.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Altın
      rankTextColor = Colors.black;
    } else if (participant.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Gümüş
      rankTextColor = Colors.black;
    } else if (participant.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronz
      rankTextColor = Colors.white;
    } else {
      rankColor = Colors.grey.shade600; // Darker grey for others
    }

    // Use a Container instead of Card for more control over the border
    return Container(
      margin: const EdgeInsets.symmetric(
          vertical: 6, horizontal: 0), // Adjusted margin
      decoration: BoxDecoration(
        color: Colors.grey.shade800, // Dark card background
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(
                color: Colors.lightGreenAccent,
                width: 2.5) // Highlight border for 'me'
            : null, // No border otherwise
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 12.0, horizontal: 16.0), // Adjusted padding
        child: Row(
          children: [
            // Profil fotoğrafı ve sıralama
            Stack(
              alignment: Alignment.center, // Center stack elements
              clipBehavior: Clip.none, // Allow badge to overflow slightly
              children: [
                // Avatar (profil fotoğrafı) - Updated to use UserProfileAvatar
                UserProfileAvatar(
                  imageUrl:
                      profilePictureUrl, // Pass the URL from cache/participant
                  radius: 25, // Slightly larger avatar
                ),

                // Sıralama rozeti (Updated Positioned Badge)
                Positioned(
                  top: -4, // Position badge overlapping the top
                  left: -4, // Position badge overlapping the left
                  child: Container(
                    width: 22, // Badge size
                    height: 22, // Badge size
                    decoration: BoxDecoration(
                      color: rankColor, // Use rank color
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.grey.shade800,
                          width: 2), // Border matching card bg
                    ),
                    child: Center(
                      child: Text(
                        participant.rank.toString(),
                        style: TextStyle(
                          fontSize: 11, // Adjusted size
                          fontWeight: FontWeight.bold,
                          color: rankTextColor, // Use dynamic text color
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Dot before username
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: participant.rank <= 3
                              ? rankColor
                              : Colors.lightGreenAccent, // Rank or green color
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        participant.userName,
                        style: const TextStyle(
                          // Simpler style, color adjusted below
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white, // White text
                        ),
                      ),
                      if (isMe)
                        const Padding(
                          padding: EdgeInsets.only(left: 6.0),
                          child: Text(
                            '(Ben)',
                            style: TextStyle(
                              fontStyle: FontStyle.normal, // Not italic
                              fontSize: 14,
                              color: Colors.grey, // Grey text
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bilgi kartları (Chips) satırı
                  Row(
                    children: [
                      // Distance Chip (conditionally shown)
                      if (!isIndoorRace)
                        _buildInfoChip(
                          label:
                              '${participant.distance.toStringAsFixed(2)} km',
                          backgroundColor:
                              Colors.blue.shade900.withOpacity(0.7),
                          textColor: Colors.blue.shade100,
                        ),
                      if (!isIndoorRace)
                        const SizedBox(width: 8), // Spacer if distance is shown
                      // Steps Chip
                      _buildInfoChip(
                        label: 'Adım: ${participant.steps}',
                        backgroundColor: Colors.green.shade900.withOpacity(0.7),
                        textColor: Colors.green.shade100,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for creating info chips like in the image
  Widget _buildInfoChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5), // Chip padding
      decoration: BoxDecoration(
        color: backgroundColor, // Chip background color
        borderRadius: BorderRadius.circular(20), // Rounded stadium border
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500, // Medium weight
          fontSize: 12, // Smaller font size
          color: textColor, // Chip text color
        ),
      ),
    );
  }
}
