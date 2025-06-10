import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Yeni import - bildirimler için
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_flutter_project/core/services/signalr_service.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/race_state.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/user_data_provider.dart'; // UserDataProvider importu

import 'package:flutter/services.dart'; // MethodChannel için

part 'race_provider.g.dart';

// Flutter Local Notifications için plugin instance'ı
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _isNotificationInitialized = false;

// Provider to track if user was kicked for cheating to show a popup on HomePage
final cheatKickedStateProvider = StateProvider<bool>((ref) => false);

@riverpod
class RaceNotifier extends _$RaceNotifier {
  // Stream abonelikleri
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<List<RaceParticipant>>? _leaderboardSubscription;
  StreamSubscription<dynamic>?
      _raceEndedSubscription; // SignalR'dan gelen raceEnded
  StreamSubscription<String?>?
      _reconnectedSubscription; // SignalR yeniden bağlanma eventi için

  // Zamanlayıcılar
  Timer? _preRaceCountdownTimer;
  Timer? _raceTimerTimer;
  Timer? _antiCheatTimer;

  // Hile kontrolü için değişkenler
  double _lastCheckDistance = 0.0;
  DateTime? _lastCheckTime;
  int _lastCheckSteps = 0;

  // Kalori Hesaplama Değişkenleri (RecordScreen'den taşındı)
  double _lastCalorieCheckDistance = 0.0;
  int _lastCalorieCheckSteps = 0;
  DateTime? _lastCalorieCalculationTime;
  Timer?
      _calorieCalculationTimer; // Ayrı bir timer veya mevcut timer'a entegre edilebilir

  @override
  RaceState build() {
    // Başlangıç durumu
    ref.onDispose(() {
      _cleanup();
    });
    return const RaceState();
  }

  // --- Ana Kontrol Metodları ---

  Future<void> startRace({
    required int roomId,
    required int countdownSeconds,
    required int raceDurationMinutes,
    required bool isIndoorRace,
    required String userEmail,
    required Map<String, String?> initialProfileCache,
    double? initialRemainingTimeSeconds,
  }) async {
    // Zaten aktif bir yarış varsa başlatma
    if (state.isRaceActive || state.isPreRaceCountdownActive) {
      return;
    }

    // Check for necessary permissions
    bool hasLocation = false;
    bool hasActivity = false;

    if (Platform.isIOS) {
      // iOS için: Geolocator ile konum izinlerini kontrol et
      final locationPermission = await Geolocator.checkPermission();
      hasLocation = locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse;

      // iOS için sensör iznini ve HealthKit iznini kontrol et
      // Hem sensör izni hem de Health Kit izinlerini kontrol etmeliyiz
      hasActivity = await Permission.sensors.isGranted;

      // HealthKit izinlerini özel olarak kontrol et - Pedometer çalışmasını test et
      try {
        // Bir Completer kullanarak HealthKit erişimini test edebiliriz
        final completer = Completer<bool>();
        StreamSubscription<StepCount>? testSubscription;

        // Health Kit'e bağlanabiliyorsak adım verisini alabiliyor olmalıyız
        testSubscription = Pedometer.stepCountStream.listen((event) {
          // Veri geldi, izin var
          if (!completer.isCompleted) {
            completer.complete(true);
            testSubscription?.cancel();
          }
        }, onError: (error) {
          // Hata geldi, izin yok veya başka sorun var
          if (!completer.isCompleted) {
            completer.complete(false);
            testSubscription?.cancel();
          }
        });

        // Kısa bir süre bekle, veri gelmezse timeout ile false dön
        Future.delayed(const Duration(seconds: 2), () {
          if (!completer.isCompleted) {
            completer.complete(false);
            testSubscription?.cancel();
          }
        });

        // HealthKit izin sonucunu bekle
        final healthKitPermission = await completer.future;

        // İzin yoksa hasActivity'yi false yap, varsa true (sensör izni önemli değil)
        hasActivity = healthKitPermission;
      } catch (e) {
        // Hata olursa izin yok kabul et
        hasActivity = false;
      }

      // Eğer izin yoksa istemeyi dene
      if (!hasLocation) {
        final requestedPermission = await Geolocator.requestPermission();
        hasLocation = requestedPermission == LocationPermission.always ||
            requestedPermission == LocationPermission.whileInUse;
      }

      if (!hasActivity) {
        final requestedSensors = await Permission.sensors.request();
      }
    } else {
      // Android için: Normal izin kontrolü değişmedi
      hasLocation = await _checkPermission(
          Permission.location); // Updated from locationAlways
      hasActivity = await _checkPermission(Permission.activityRecognition);
    }

    // State'i ilk değerlerle güncelle
    state = RaceState(
      roomId: roomId,
      isIndoorRace: isIndoorRace,
      isPreRaceCountdownActive: true,
      preRaceCountdownValue: countdownSeconds,
      raceDuration: Duration(minutes: raceDurationMinutes),
      userEmail: userEmail,
      hasLocationPermission: hasLocation,
      hasPedometerPermission: hasActivity,
      profilePictureCache: initialProfileCache, // <-- Store the cache
      currentCalories: 0, // Başlangıç kalorisi
      estimatedIndoorDistance: 0.0, // Tahmini iç mekan mesafesini başlat
      // Kalori hesaplama için başlangıç değerleri
    );
    _lastCalorieCheckDistance = 0.0;
    _lastCalorieCheckSteps = 0;
    _lastCalorieCalculationTime = null;

    _startPreRaceCountdown(
        initialRemainingTimeSecondsForTimer: initialRemainingTimeSeconds);
  }

  Future<void> leaveRace() async {
    // Önce SignalR'dan ayrılmayı dene
    try {
      final signalRService = ref.read(signalRServiceProvider);
      if (signalRService.isConnected && state.roomId != null) {
        signalRService.leaveRoomDuringRace(state
            .roomId!); // Notifier method name should match the one in SignalRService
      }
    } catch (e) {
      // SignalR hatası ayrılmayı engellememeli
    }

    // SignalR denemesinden sonra kaynakları temizle
    await _cleanup(); // Ensure cleanup awaits if it's async

    // --- DEĞİŞİKLİK: State'i resetlemek yerine hata mesajı ayarla ---
    state = state.copyWith(
        isRaceActive: false,
        isPreRaceCountdownActive: false,
        errorMessage: 'Yarıştan ayrıldınız.', // Ayrılma durumunu belirt
        isRaceFinished: false, // Yarış normal bitmedi
        showFirstCheatWarning: false // Uyarıyı temizle
        );
  }

  // --- İç Yardımcı Metodlar ---

  // İzin kontrolü (UI göstermeden)
  Future<bool> _checkPermission(Permission permission) async {
    // iOS için Geolocator kullan, Android için Permission kalacak
    if (Platform.isIOS && permission == Permission.location) {
      // iOS için Geolocator ile konum izinlerini kontrol et
      final locationPermission = await Geolocator.checkPermission();

      // Always veya WhileInUse izni yeterli olacak
      return locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse;
    } else {
      // Android için veya konum dışı izinlerde normal Permission kullan
      final status = await permission.status;
      return status.isGranted || status.isLimited;
    }
  }

  void _startPreRaceCountdown({double? initialRemainingTimeSecondsForTimer}) {
    _preRaceCountdownTimer?.cancel();
    // State'in zaten doğru ayarlandığını varsayıyoruz startRace içinde
    // state = state.copyWith(isPreRaceCountdownActive: true, preRaceCountdownValue: state.preRaceCountdownValue);

    _preRaceCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      // Timer çalıştığında state'i tekrar kontrol et (güvenlik için)
      if (!state.isPreRaceCountdownActive) {
        timer.cancel();
        _preRaceCountdownTimer = null; // Timer'ı null yap
        return;
      }

      final currentCountdown = state.preRaceCountdownValue;

      if (currentCountdown > 0) {
        state = state.copyWith(preRaceCountdownValue: currentCountdown - 1);
      } else {
        timer.cancel();
        _preRaceCountdownTimer = null;
        // ÖNEMLİ: State'i güncellemeden önce mevcut state'i kontrol et
        if (state.isPreRaceCountdownActive) {
          // Hala geri sayım modundaysak
          state = state.copyWith(
              isPreRaceCountdownActive: false, isRaceActive: true);
          _startActualRaceTracking(
            initialRemainingTimeSeconds: initialRemainingTimeSecondsForTimer,
          ); // Geri sayım bitti, asıl takibi başlat
        }
      }
    });
  }

  void _startActualRaceTracking({double? initialRemainingTimeSeconds}) async {
    state = state.copyWith(raceStartTime: DateTime.now());

    _listenToSignalREvents();
    _initializeRaceTimer(
        initialRemainingTimeSeconds: initialRemainingTimeSeconds);
    // Kalori hesaplama timer'ını başlat (veya _raceTimerTimer içine entegre et)
    _initializeCalorieCalculation(); // <-- Yeni metod çağrısı

    if (!state.isIndoorRace) {
      _initializeAntiCheatSystem();
    }

    // iOS için özel gecikme stratejisi
    if (Platform.isIOS) {
      // HealthKit bağlantısı için kısa bir gecikme
      // SignalR ve diğer işlemlerin tamamlanması için bekleyelim
      Future.delayed(const Duration(milliseconds: 300), () {
        if (state.hasPedometerPermission) {
          _initPedometer();
        }
      });

      // Yedek olarak belirli bir süre sonra tekrar deneyelim (bazı cihazlarda gerekebilir)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (state.isRaceActive &&
            state.initialSteps == 0 &&
            state.hasPedometerPermission) {
          _initPedometer();
        }
      });

      // Konum izinleri varsa ve iç mekan yarışı değilse konum takibini başlat
      if (state.hasLocationPermission && !state.isIndoorRace) {
        _startLocationUpdates();
      }
    } else {
      // Android için standart başlatma stratejisi - değişiklik yok
      if (state.hasPedometerPermission) {
        _initPedometer();
      }
      if (state.hasLocationPermission && !state.isIndoorRace) {
        _startLocationUpdates();
      }
    }
  }

  void _listenToSignalREvents() {
    final signalRService = ref.read(signalRServiceProvider);

    _leaderboardSubscription?.cancel();
    _leaderboardSubscription =
        signalRService.leaderboardStream.listen((leaderboard) {
      if (!state.isRaceActive) return; // Yarış aktif değilse güncelleme
      state = state.copyWith(leaderboard: leaderboard);
    });

    _raceEndedSubscription?.cancel();
    _raceEndedSubscription =
        signalRService.raceEndedStream.listen((endedRoomId) {
      if (!state.isRaceActive ||
          state.roomId == null ||
          endedRoomId != state.roomId) return;
      _handleRaceEnd();
    });

    _reconnectedSubscription?.cancel(); // Önceki varsa iptal et
    _reconnectedSubscription =
        signalRService.reconnectedStream.listen((String? newConnectionId) {
      if (newConnectionId != null) {
        if (state.isRaceActive && state.roomId != null) {
          try {
            signalRService
                .joinRaceRoom(state.roomId!)
                .then((_) {})
                .catchError((e) {});
          } catch (e) {}
        }
      }
    });
    // Diğer SignalR eventleri (userJoined, userLeft) UI tarafından dinlenebilir veya burada ele alınabilir.
  }

  void _handleRaceEnd() async {
    // Prevent running if already finished
    if (state.isRaceFinished || !state.isRaceActive) {
      return;
    }
    await _cleanup();

    // Now update the state to indicate the race is finished normally
    state = state.copyWith(
      isRaceActive: false,
      isRaceFinished: true, // Set the finished flag
      remainingTime: Duration.zero, // Ensure remaining time is zero
    );
  }

  void _initializeRaceTimer({double? initialRemainingTimeSeconds}) {
    _raceTimerTimer?.cancel();
    if (state.raceDuration == null) return;

    Duration actualStartingRemainingTime;
    if (initialRemainingTimeSeconds != null &&
        initialRemainingTimeSeconds > 0) {
      // Eğer dışarıdan bir kalan süre geldiyse (yarışa ortadan katılındıysa) onu kullan
      actualStartingRemainingTime =
          Duration(seconds: initialRemainingTimeSeconds.round());
    } else {
      // Yoksa yarışın toplam süresini kullan (yeni başlıyorsa)
      actualStartingRemainingTime = state.raceDuration!;
    }
    state = state.copyWith(remainingTime: actualStartingRemainingTime);

    _raceTimerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRaceActive) {
        timer.cancel();
        return;
      }
      if (state.remainingTime.inSeconds > 0) {
        state = state.copyWith(
            remainingTime: state.remainingTime - const Duration(seconds: 1));
      } else {
        timer.cancel();
        _raceTimerTimer = null;
      }
    });
  }

  // Kalori Hesaplama Başlatma
  void _initializeCalorieCalculation() {
    _calorieCalculationTimer?.cancel();
    // Her 5 saniyede bir hesapla
    _calorieCalculationTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      _calculateCalories();
    });
  }

  // Kalori Hesaplama Metodu (RecordScreen'den uyarlandı)
  void _calculateCalories() {
    final now = DateTime.now();

    if (_lastCalorieCalculationTime == null) {
      _lastCalorieCheckDistance = state.currentDistance;
      _lastCalorieCheckSteps = state.currentSteps;
      _lastCalorieCalculationTime = now;
      return;
    }

    final elapsedSeconds =
        now.difference(_lastCalorieCalculationTime!).inSeconds;
    // Minimum süreyi 4 saniyeye düşürelim (5 saniyelik periyot için)
    if (elapsedSeconds < 4) return; // Avoid rapid recalculation

    final distanceDifference =
        state.currentDistance - _lastCalorieCheckDistance;
    final stepsDifference = state.currentSteps - _lastCalorieCheckSteps;
    final bool isMoving = distanceDifference > 0.001 || stepsDifference > 0;
    final double currentPaceKmH = distanceDifference > 0 && elapsedSeconds > 0
        ? (distanceDifference) / (elapsedSeconds / 3600.0)
        : 0;

    // 1. Kullanıcı Verilerini Al (Varsayılan Değerlerle)
    final userData = ref.read(userDataProvider).value;
    double weightKg = 70.0; // Varsayılan kilo
    double heightCm = 170.0; // Varsayılan boy
    int ageYears = 25; // Varsayılan yaş
    String gender = 'male'; // Varsayılan cinsiyet (veya 'female')

    if (userData != null) {
      weightKg = (userData.weight != null && userData.weight! > 0)
          ? userData.weight!
          : weightKg;
      heightCm = (userData.height != null && userData.height! > 0)
          ? userData.height!
          : heightCm;
      ageYears = (userData.age != null && userData.age! > 0)
          ? userData.age!
          : ageYears;
      // Cinsiyet verisinin nasıl saklandığına bağlı olarak kontrol et ('male'/'female', 'erkek'/'kadın' vb.)
      // Şimdilik 'gender' alanının 'male' veya 'female' string'i içerdiğini varsayalım.
      gender = userData.gender?.toLowerCase() == 'female' ? 'female' : 'male';
    } else {}

    // 2. Bazal Metabolizma Hızını (BMR) Hesapla (Mifflin-St Jeor)
    double bmr;
    if (gender == 'female') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161;
    } else {
      // male or default
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5;
    }
    // Negatif BMR olmasını engelle
    if (bmr < 0) bmr = 0;

    // 3. Aktivite Yoğunluğuna Göre MET Değeri Belirle (İyileştirilmiş)
    // Compendium of Physical Activities referans alınabilir.
    double metValue;
    if (!isMoving) {
      metValue = 1.0; // Dinlenme MET
    } else {
      // Aktivite tipine göre MET belirle
      if (state.isIndoorRace) {
        // İç Mekan: Adım sıklığına (kadans) göre MET belirle
        double cadence = 0;
        if (elapsedSeconds > 0) {
          // Kadansı dakika başına adım (SPM - Steps Per Minute) olarak hesapla
          cadence = (stepsDifference / elapsedSeconds.toDouble()) * 60.0;
        }
        if (cadence <= 0) {
          metValue = 1.0; // Hareket yok veya hata
        } else if (cadence < 80) {
          // Çok yavaş yürüme
          metValue = 2.5;
        } else if (cadence < 100) {
          // Normal yürüme
          metValue = 3.0;
        } else if (cadence < 120) {
          // Tempolu yürüme / Çok hafif jog
          metValue = 3.8;
        } else if (cadence < 140) {
          // Hafif Jog / Kolay Koşu
          metValue = 6.0;
        } else if (cadence < 160) {
          // Orta tempo koşu
          metValue = 8.3; // 8.0 - 9.0 aralığı olabilir
        } else if (cadence < 180) {
          // Hızlı koşu
          metValue = 10.0; // 9.8 - 11.0 aralığı olabilir
        } else {
          // Çok hızlı koşu / Sprint
          metValue = 11.8; // 11.5+ olabilir
        }
      } else {
        // Dış Mekan: GPS hızına göre MET belirle (Mevcut mantık)
        if (currentPaceKmH < 3.2) {
          // ~2.0 mph (Slow walking)
          metValue = 2.0;
        } else if (currentPaceKmH < 4.8) {
          // ~3.0 mph (Moderate walking)
          metValue = 3.0; // veya 3.5 (brisk)
        } else if (currentPaceKmH < 6.4) {
          // ~4.0 mph (Very brisk walking)
          metValue = 3.8; // veya 5.0 (very very brisk/race walking pace start)
        }
        // Koşu hızları
        else if (currentPaceKmH < 8.0) {
          // ~5.0 mph (Light jog)
          metValue = 8.3;
        } else if (currentPaceKmH < 9.7) {
          // ~6.0 mph (Moderate run)
          metValue = 9.8;
        } else if (currentPaceKmH < 11.3) {
          // ~7.0 mph
          metValue = 11.0;
        } else if (currentPaceKmH < 12.9) {
          // ~8.0 mph
          metValue = 11.8;
        } else if (currentPaceKmH < 14.5) {
          // ~9.0 mph
          metValue = 12.8;
        } else if (currentPaceKmH < 16.0) {
          // ~10.0 mph
          metValue = 14.5;
        } else if (currentPaceKmH < 17.5) {
          // ~11.0 mph
          metValue = 16.0;
        } else {
          // ~12.0 mph+
          metValue = 19.0;
        }
      }
    }

    // 4. Toplam Kaloriyi Hesapla (BMR * MET * Süre)
    // BMR günlük kalori, saniyeliğe çevirip MET ve süre ile çarp
    double bmrPerSecond = bmr / (24 * 60 * 60);
    int newCalories = (bmrPerSecond * elapsedSeconds * metValue).round();
    if (newCalories < 0) newCalories = 0;

    state =
        state.copyWith(currentCalories: state.currentCalories + newCalories);

    _lastCalorieCheckDistance = state.currentDistance;
    _lastCalorieCheckSteps = state.currentSteps;
    _lastCalorieCalculationTime = now;
  }

  void _initializeAntiCheatSystem() {
    _lastCheckDistance = state.currentDistance;
    _lastCheckSteps = state.currentSteps;
    _lastCheckTime = DateTime.now(); // Initialize for the first check
    state = state.copyWith(violationCount: 0);

    _antiCheatTimer?.cancel(); // Cancel any existing timer

    // Check every 30 seconds. _checkForCheating has an internal check for elapsed time.
    const Duration checkInterval = Duration(seconds: 30);
    _antiCheatTimer = Timer.periodic(checkInterval, (timer) {
      if (!state.isRaceActive) {
        timer.cancel();
        _antiCheatTimer = null; // Clear the timer reference
        return;
      }
      // _checkForCheating itself will handle the logic based on _lastCheckTime
      // and will return if the race is not active or if _lastCheckTime is null.
      _checkForCheating();
    });
  }

  void _checkForCheating() {
    if (_lastCheckTime == null || !state.isRaceActive) return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastCheckTime!).inSeconds;
    if (elapsedSeconds < 25) return; // Kontrol sıklığını koruyalım

    final distanceDifference =
        (state.currentDistance - _lastCheckDistance) * 1000; // m
    final stepsDifference = state.currentSteps - _lastCheckSteps;

    bool violation = false;
    String checkTypeLog = ""; // Log için değişken

    // **** YARIŞ TÜRÜNE GÖRE KONTROL ****
    if (state.isIndoorRace) {
      // === SADECE INDOOR KONTROLÜ: KADANS ===
      checkTypeLog = "(Indoor)";
      if (elapsedSeconds > 0 && stepsDifference > 0) {
        // Süre ve adım varsa hesapla
        final double cadence = stepsDifference / elapsedSeconds.toDouble();
        const double maxRealisticCadence =
            5.0; // Saniyede 5 adımdan fazla sürekli olamaz
        if (cadence > maxRealisticCadence) {
          violation = true;
        }
      }
      // =======================================
    } else {
      // === SADECE OUTDOOR KONTROLÜ: MESAFE/ADIM ===
      checkTypeLog = "(Outdoor)";
      // 1. Aşırı Hız Kontrolü
      if (distanceDifference > 250) {
        violation = true;
      }
      // 2. Adım-Mesafe Tutarlılık Kontrolü (Sadece anlamlı mesafe varsa)
      else if (distanceDifference > 0) {
        final requiredMinSteps = distanceDifference * 0.5;
        if (stepsDifference < requiredMinSteps) {
          violation = true;
        }
      }
    }

    // **** ORTAK İHLAL YÖNETİMİ ****
    if (violation) {
      final newViolationCount = state.violationCount + 1;

      if (newViolationCount == 1) {
        // First violation: Set flag to show warning

        state = state.copyWith(
            violationCount: newViolationCount, showFirstCheatWarning: true);
        // Do not kick yet
      } else if (newViolationCount >= 2) {
        // Second violation: Kick the user
        ref.read(cheatKickedStateProvider.notifier).state = true;
        state = state.copyWith(
            violationCount: newViolationCount,
            showFirstCheatWarning: false, // Ensure warning flag is off
            errorMessage:
                'Anormal aktivite nedeniyle yarıştan çıkarıldınız.' // More specific message
            );
        leaveRace(); // Kick the user
      }
    }

    _lastCheckDistance = state.currentDistance;
    _lastCheckSteps = state.currentSteps;
    _lastCheckTime = now;
  }

  void _initPedometer() {
    _stepCountSubscription?.cancel();
    state = state.copyWith(initialSteps: 0, currentSteps: 0); // Reset steps

    try {
      // iOS ve Android için ortak işlemler
      if (Platform.isIOS) {
        // iOS için özel pedometer başlatma yöntemi
        _initPedometerIOS();
      } else {
        // Android için pedometer başlatma
        _initPedometerAndroid();
      }
    } catch (e) {
      state = state.copyWith(
          errorMessage:
              'Adım sayar başlatılırken bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  // iOS için özel pedometer başlatma metodu
  void _initPedometerIOS() {
    Future.delayed(const Duration(milliseconds: 50), () {
      // İlk başlatma denemesi
      _attemptStepCountListening(isFirstAttempt: true);

      // Farklı zamanlarda çoklu deneme - HealthKit bazen gecikmeli yanıt verebiliyor
      Future.delayed(const Duration(seconds: 1), () {
        if (state.isRaceActive && state.initialSteps == 0) {
          _attemptStepCountListening(retryCount: 1);
        }
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (state.isRaceActive && state.initialSteps == 0) {
          _attemptStepCountListening(retryCount: 2);
        }
      });

      Future.delayed(const Duration(seconds: 7), () {
        if (state.isRaceActive && state.initialSteps == 0) {
          _attemptStepCountListening(retryCount: 3);

          // Kullanıcıya bilgi vermek için state'i güncelle
          if (state.initialSteps == 0) {
            state = state.copyWith(
                // Manuel başlatma için adım 1'den başlat
                initialSteps: 1,
                currentSteps: 0,
                errorMessage:
                    'Adım verileri almakta zorluk yaşıyoruz. Apple Health uygulamasını açıp adım erişimini onayladığınızdan emin olun.');
          }
        }
      });
    });
  }

  // Tekrar kullanılabilir step count dinleme metodu - iOS için
  void _attemptStepCountListening(
      {int retryCount = 0, bool isFirstAttempt = false}) {
    // Eğer önceki bir subscription varsa iptal et
    if (retryCount > 0) {
      _stepCountSubscription?.cancel();
    }

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          final int stepValue = event.steps;

          if (!state.isRaceActive) {
            return;
          }

          // Eğer initialSteps henüz ayarlanmamışsa
          if (state.initialSteps == 0 && stepValue > 0) {
            state = state.copyWith(
                initialSteps: stepValue,
                currentSteps: 0,
                errorMessage: null // Hata varsa temizle
                );

            // Başlangıç değeri ayarlandı, sunucuya bildir
            _updateLocation();
          } else if (state.initialSteps > 0) {
            // İlk değer ayarlandıysa adımları hesapla
            int calculatedSteps = stepValue - state.initialSteps;
            if (calculatedSteps < 0) calculatedSteps = 0;

            // Sadece değişiklik varsa güncelle
            if (calculatedSteps != state.currentSteps) {
              state = state.copyWith(currentSteps: calculatedSteps);

              // Adımlar değişti, sunucuya bildir ve iç mekan mesafesini hesapla
              _updateLocation();
              _calculateAndUpdateEstimatedIndoorDistance();
            }
          }
        },
        onError: (error) {
          if (retryCount >= 2) {
            state = state.copyWith(
                errorMessage:
                    'Adım verisi alınamıyor. Apple Health iznini kontrol edin.');
          }
        },
        cancelOnError: false, // Hatalarda otomatik iptal etme
      );
    } catch (e) {
      if (retryCount >= 2) {
        state = state.copyWith(
            errorMessage:
                'Adım ölçüm başlatılamadı. iOS Health ayarlarını kontrol edin.');
      }
    }
  }

  // Android için pedometer başlatma metodu
  void _initPedometerAndroid() {
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (!state.isRaceActive) {
          return;
        }

        // İlk adım sayısını kaydet
        if (state.initialSteps == 0) {
          state = state.copyWith(initialSteps: event.steps, currentSteps: 0);
          // İlk adımlar ayarlandı, sunucuya bildir ve iç mekan mesafesini hesapla
          _updateLocation();
          _calculateAndUpdateEstimatedIndoorDistance();
        } else {
          // Adım farkını hesapla
          int calculatedSteps = event.steps - state.initialSteps;
          if (calculatedSteps < 0) calculatedSteps = 0;

          if (calculatedSteps != state.currentSteps) {
            state = state.copyWith(currentSteps: calculatedSteps);
            // Adım değişti, sunucuya bildir ve iç mekan mesafesini hesapla
            _updateLocation();
            _calculateAndUpdateEstimatedIndoorDistance();
          }
        }
      },
      onError: (error) {
        state = state.copyWith(
            errorMessage:
                'Adım verisi alınamıyor. Uygulama izinlerini kontrol edin.');

        // Android için tekrar deneme
        if (state.isRaceActive && state.initialSteps == 0) {
          _stepCountSubscription?.cancel();
          Future.delayed(const Duration(seconds: 1), () {
            _initPedometerAndroid(); // Tekrar başlatmayı dene
          });
        }
      },
      cancelOnError: false,
    );
  }

  // Yeni metod: İç mekan için tahmini mesafeyi hesapla ve state'i güncelle
  void _calculateAndUpdateEstimatedIndoorDistance() {
    if (state.isIndoorRace && state.isRaceActive) {
      final userData = ref.read(userDataProvider).value;
      final double? userHeightCm = userData?.height;

      if (userHeightCm != null && userHeightCm > 0) {
        // Adım uzunluğu (metre cinsinden) = Boy (cm) * 0.00414 (yaygın bir yaklaşım)
        // Veya Boy (cm) * 0.414 / 100
        final double stepLengthMeters = userHeightCm * 0.00414;
        final double estimatedDistanceKm =
            (state.currentSteps * stepLengthMeters) / 1000.0;

        if (state.estimatedIndoorDistance != estimatedDistanceKm) {
          state = state.copyWith(estimatedIndoorDistance: estimatedDistanceKm);
        }
      } else {
        // Boy bilgisi yoksa veya geçersizse, tahmini mesafeyi 0 yap veya mevcut değeri koru
        if (state.estimatedIndoorDistance != 0.0) {
          state = state.copyWith(estimatedIndoorDistance: 0.0);
        }
      }
    }
  }

  void _startLocationUpdates() {
    if (state.isIndoorRace ||
        !state.hasLocationPermission ||
        !state.isRaceActive) {
      return;
    }

    _positionStreamSubscription?.cancel();

    _initializeLocationStream();
  }

  // Konum takibi stream'ini başlatan yardımcı metot (platformdan bağımsız)
  void _initializeLocationStream() {
    LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Movliq yarış sırasında konumunuzu takip ediyor.",
          notificationTitle: "Movliq Yarışı Devam Ediyor",
          notificationIcon:
              AndroidResource(name: 'launcher_icon', defType: 'mipmap'),
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        // Kilit ekranında çalışması için arka plan ayarlarını etkinleştir
        allowBackgroundLocationUpdates: true,
      );

      // iOS için bildirim gösterme - iOS 10.0+ için bildirim
      // iOS, Android'den farklı olarak bildirimi burada değil, uygulama içinde ayrıca göstermemiz gerekiyor
      _showIOSNotification("Movliq yarış devam ediyor", "Konum takibi aktif");
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    Position? lastPosition;
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!state.isRaceActive) return;

      double newDistancePortion = 0.0;
      if (lastPosition != null) {
        newDistancePortion = Geolocator.distanceBetween(
              lastPosition!.latitude,
              lastPosition!.longitude,
              position.latitude,
              position.longitude,
            ) /
            1000; // km cinsinden
      }
      lastPosition = position;

      state = state.copyWith(
          currentDistance: state.currentDistance + newDistancePortion);
      _updateLocation(); // Konum değiştiğinde sunucuya bildir
    }, onError: (error) {});
  }

  // iOS arka plan konum modunu etkinleştir
  void _setIOSBackgroundLocationActive() {
    if (!Platform.isIOS) return;

    try {
      // iOS'un CLLocationManager arka plan modu için ek ayarlar
      // Bu metod Geolocator paketinin önerdiği çözümü uyguluyor

      Geolocator.checkPermission().then((permission) {
        if (permission == LocationPermission.always) {
          // iOS'un arka plan modu için sistemdeki "significant-change" servisi etkinleştirilmeli
          // Bu, enerji tasarrufu için iOS'un konum güncellemelerini optimize etmesini sağlar
          Geolocator.getServiceStatusStream().listen((status) {});

          Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).then((position) {}).catchError((e) {});
        }
      });
    } catch (e) {}
  }

  Future<void> _updateLocation() async {
    if (!state.isRaceActive || state.roomId == null) return;

    final signalRService = ref.read(signalRServiceProvider);
    if (!signalRService.isConnected) return;

    try {
      double distanceToSend = state.isIndoorRace ? 0.0 : state.currentDistance;
      // Kaloriyi de gönder
      await signalRService.updateLocation(
        state.roomId!,
        distanceToSend,
        state.currentSteps,
        state.currentCalories, // Kaloriyi ekle
      );
    } catch (e) {}
  }

  Future<void> _cleanup() async {
    _preRaceCountdownTimer?.cancel();
    _raceTimerTimer?.cancel();
    _antiCheatTimer?.cancel();
    _calorieCalculationTimer?.cancel(); // Kalori timer'ını da iptal et
    _positionStreamSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _raceEndedSubscription?.cancel();
    _reconnectedSubscription?.cancel();

    _preRaceCountdownTimer = null;
    _raceTimerTimer = null;
    _antiCheatTimer = null;
    _calorieCalculationTimer = null;
    _positionStreamSubscription = null;
    _stepCountSubscription = null;
    _leaderboardSubscription = null;
    _raceEndedSubscription = null;
    _reconnectedSubscription = null;

    // iOS için özel temizleme işlemleri
    if (Platform.isIOS) {
      // Bildirimler
      await _cancelIOSNotification();
    }
  }

  // iOS için bildirim gösterme ve yönetme metodları
  Future<void> _initializeNotifications() async {
    if (_isNotificationInitialized) return;

    // iOS bildirimleri için
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false, // İzinleri zaten başka yerde istiyoruz
    );

    // Android bildirimleri için (zaten ForegroundNotificationConfig'i kullanıyoruz, ama yine de ayarlayalım)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    // Uygulama için bildirim ayarlarını initialize et
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      _isNotificationInitialized = true;
    } catch (e) {}
  }

  // iOS için bildirim gösterme
  Future<void> _showIOSNotification(String title, String body) async {
    if (!Platform.isIOS) return;

    // Bildirimleri başlat
    await _initializeNotifications();

    // iOS için bildirim detayları
    const DarwinNotificationDetails iOSNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: 'movliq_race_tracking',
    );

    // Bildirim detayları
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: iOSNotificationDetails,
      android: null, // Android için null, çünkü ForegroundService kullanıyoruz
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        1, // Notification ID (aynı ID ile bildirim güncellenecek)
        title,
        body,
        notificationDetails,
      );
    } catch (e) {}
  }

  // iOS için bildirimi iptal etme
  Future<void> _cancelIOSNotification() async {
    if (!Platform.isIOS || !_isNotificationInitialized) return;

    try {
      await flutterLocalNotificationsPlugin
          .cancel(1); // ID:1 ile gösterilen bildirimi iptal et
    } catch (e) {}
  }

  // --- Yeni Metod: İlk Hile Uyarısını Kapatma ---
  void dismissFirstCheatWarning() {
    if (state.showFirstCheatWarning) {
      final bool raceActuallyFinished =
          state.isRaceActive && state.remainingTime <= Duration.zero;
      if (raceActuallyFinished) {
        state = state.copyWith(showFirstCheatWarning: false);
        _handleRaceEnd(); // Yarış bitirme mantığını tetikle
      }
    }
  }
}
