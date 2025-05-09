import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'; // debugPrint için
import 'package:flutter/material.dart'; // Yeni import - bildirimler için
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Yeni import - bildirimler için
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_flutter_project/core/services/signalr_service.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/race_state.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/user_data_provider.dart'; // UserDataProvider importu
import 'package:my_flutter_project/features/auth/domain/models/user_data_model.dart'; // UserDataModel importu
import 'package:flutter/services.dart'; // MethodChannel için

part 'race_provider.g.dart';

// Flutter Local Notifications için plugin instance'ı
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
bool _isNotificationInitialized = false;

@riverpod
class RaceNotifier extends _$RaceNotifier {
  // Stream abonelikleri
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<List<RaceParticipant>>? _leaderboardSubscription;
  StreamSubscription<dynamic>?
      _raceEndedSubscription; // SignalR'dan gelen raceEnded

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
      debugPrint('RaceNotifier: Disposing - Cleaning up resources...');
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
    required String userEmail, // Kullanıcı email'ini başta alalım
    required Map<String, String?> initialProfileCache, // <-- Add cache param
  }) async {
    debugPrint(
        '--- RaceNotifier: startRace CALLED --- Room: $roomId, Countdown: $countdownSeconds, Duration (minutes): $raceDurationMinutes <--- TYPE CHECK: ${raceDurationMinutes.runtimeType}, Indoor: $isIndoorRace, Email: $userEmail');

    // Zaten aktif bir yarış varsa başlatma
    if (state.isRaceActive || state.isPreRaceCountdownActive) {
      debugPrint(
          '--- RaceNotifier: Yarış zaten aktif veya başlamak üzere, yeni yarış başlatılmadı ---');
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
      
      debugPrint(
        '--- RaceNotifier: iOS İzinler - Location: $hasLocation (${locationPermission.toString()}), Activity Sensor: $hasActivity ---');
      
      // HealthKit izinlerini özel olarak kontrol et - Pedometer çalışmasını test et
      try {
        // Bir Completer kullanarak HealthKit erişimini test edebiliriz
        final completer = Completer<bool>();
        StreamSubscription<StepCount>? testSubscription;
        
        // Health Kit'e bağlanabiliyorsak adım verisini alabiliyor olmalıyız
        testSubscription = Pedometer.stepCountStream.listen(
          (event) {
            // Veri geldi, izin var
            if (!completer.isCompleted) {
              debugPrint('--- RaceNotifier: HealthKit test - Adım verisi alındı: ${event.steps} ---');
              completer.complete(true);
              testSubscription?.cancel();
            }
          },
          onError: (error) {
            // Hata geldi, izin yok veya başka sorun var
            if (!completer.isCompleted) {
              debugPrint('--- RaceNotifier: HealthKit test - Hata: $error ---');
              completer.complete(false);
              testSubscription?.cancel();
            }
          }
        );
        
        // Kısa bir süre bekle, veri gelmezse timeout ile false dön
        Future.delayed(const Duration(seconds: 2), () {
          if (!completer.isCompleted) {
            debugPrint('--- RaceNotifier: HealthKit test - Timeout oldu, izin yok veya veri gelmiyor ---');
            completer.complete(false);
            testSubscription?.cancel();
          }
        });
        
        // HealthKit izin sonucunu bekle
        final healthKitPermission = await completer.future;
        
        // İzin yoksa hasActivity'yi false yap, varsa true (sensör izni önemli değil)
        hasActivity = healthKitPermission;
        debugPrint('--- RaceNotifier: iOS HealthKit test sonucu: $hasActivity ---');
      } catch (e) {
        // Hata olursa izin yok kabul et
        debugPrint('--- RaceNotifier: iOS HealthKit test hatası: $e ---');
        hasActivity = false;
      }
      
      // Eğer izin yoksa istemeyi dene
      if (!hasLocation) {
        final requestedPermission = await Geolocator.requestPermission();
        hasLocation = requestedPermission == LocationPermission.always || 
                      requestedPermission == LocationPermission.whileInUse;
        debugPrint('--- RaceNotifier: iOS konum izni istendi, sonuç: $hasLocation (${requestedPermission.toString()}) ---');
      }
      
      if (!hasActivity) {
        final requestedSensors = await Permission.sensors.request();
        // Sadece sensör izni yeterli değil, zaten HealthKit'i test ettik
        // hasActivity = requestedSensors.isGranted; 
        debugPrint('--- RaceNotifier: iOS sensör izni istendi, sonuç: ${requestedSensors.isGranted} ---');
        debugPrint('--- RaceNotifier: iOS için HealthKit izni alamadık, kullanıcı Health uygulamasını açıp izin vermeli ---');
      }
    } else {
      // Android için: Normal izin kontrolü değişmedi
      hasLocation = await _checkPermission(Permission.locationAlways);
      hasActivity = await _checkPermission(Permission.activityRecognition);
      debugPrint(
        '--- RaceNotifier: Android İzinler - Location: $hasLocation, Activity: $hasActivity ---');
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
      // Kalori hesaplama için başlangıç değerleri
    );
    _lastCalorieCheckDistance = 0.0;
    _lastCalorieCheckSteps = 0;
    _lastCalorieCalculationTime = null;

    debugPrint(
        '--- RaceNotifier: Initial state SET --- State: $state'); // <-- YENİ LOG

    // Geri sayımı başlat
    _startPreRaceCountdown();
  }

  Future<void> leaveRace() async {
    debugPrint('RaceNotifier: Yarıştan ayrılınıyor...');

    // Önce SignalR'dan ayrılmayı dene
    try {
      final signalRService = ref.read(signalRServiceProvider);
      if (signalRService.isConnected && state.roomId != null) {
        debugPrint(
            'RaceNotifier: Calling signalRService.leaveRoomDuringRace for roomId: ${state.roomId}');
        // Ayrılma komutunu gönder (sonucu beklemesek de olur, en iyi çaba)
        signalRService.leaveRoomDuringRace(state
            .roomId!); // Notifier method name should match the one in SignalRService
        debugPrint(
            'RaceNotifier: leaveRoomDuringRace command sent (fire and forget).');
      } else {
        debugPrint(
            'RaceNotifier: SignalR not connected or roomId is null, skipping leaveRoomDuringRace call.');
      }
    } catch (e) {
      // SignalR hatası ayrılmayı engellememeli
      debugPrint(
          'RaceNotifier: SignalR odasından ayrılırken hata (yoksayılıyor): $e');
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
    // state = const RaceState(); // ESKİ: State'i başlangıç durumuna döndür
    // --- DEĞİŞİKLİK SONU ---\n\n    debugPrint(\n        \'RaceNotifier: Cleanup finished and state updated for leaving race.\');\n  }\n\n  // ... (diğer metodlar) ...\n\n  // --- Yeni Metod: İlk Hile Uyarısını Kapatma --- \n  void dismissFirstCheatWarning() {\n    if (state.showFirstCheatWarning) {\n      debugPrint(\'RaceNotifier: Dismissing first cheat warning.\');\n      // --- DEĞİŞİKLİK: Uyarıyı kapatırken yarışın bitip bitmediğini kontrol et --- \n      final bool raceActuallyFinished = state.isRaceActive && state.remainingTime <= Duration.zero;\n      if (raceActuallyFinished) {\n         debugPrint(\'RaceNotifier: Warning dismissed, but race had already finished. Triggering race end.\');\n         // Uyarıyı kapat ve yarışı bitir\n         state = state.copyWith(showFirstCheatWarning: false);\n         _handleRaceEnd(); // Yarış bitirme mantığını tetikle\n      } else {\n         // Sadece uyarıyı kapat\n         state = state.copyWith(showFirstCheatWarning: false);\n      }\n      // --- DEĞİŞİKLİK SONU ---\n    }\n  }\n

    debugPrint(
        'RaceNotifier: Cleanup finished and state updated for leaving race.');
  }

  // --- İç Yardımcı Metodlar ---

  // İzin kontrolü (UI göstermeden)
  Future<bool> _checkPermission(Permission permission) async {
    // iOS için Geolocator kullan, Android için Permission kalacak
    if (Platform.isIOS && permission == Permission.locationAlways) {
      // iOS için Geolocator ile konum izinlerini kontrol et
      final locationPermission = await Geolocator.checkPermission();
      debugPrint('RaceNotifier: iOS konum izni durumu: $locationPermission');
      
      // Always veya WhileInUse izni yeterli olacak
      return locationPermission == LocationPermission.always || 
             locationPermission == LocationPermission.whileInUse;
    } else {
      // Android için veya konum dışı izinlerde normal Permission kullan
      final status = await permission.status;
      return status.isGranted || status.isLimited;
    }
  }

  void _startPreRaceCountdown() {
    debugPrint(
        '--- RaceNotifier: _startPreRaceCountdown CALLED --- Initial Countdown: ${state.preRaceCountdownValue}'); // <-- YENİ LOG
    _preRaceCountdownTimer?.cancel();
    // State'in zaten doğru ayarlandığını varsayıyoruz startRace içinde
    // state = state.copyWith(isPreRaceCountdownActive: true, preRaceCountdownValue: state.preRaceCountdownValue);

    _preRaceCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      // Timer çalıştığında state'i tekrar kontrol et (güvenlik için)
      if (!state.isPreRaceCountdownActive) {
        debugPrint(
            '--- RaceNotifier: Countdown timer tick, but state says countdown not active! Cancelling timer. State: $state'); // <-- YENİ LOG
        timer.cancel();
        _preRaceCountdownTimer = null; // Timer'ı null yap
        return;
      }

      final currentCountdown = state.preRaceCountdownValue;
      debugPrint(
          '--- RaceNotifier: Countdown tick: $currentCountdown -> ${currentCountdown - 1} ---'); // <-- YENİ LOG

      if (currentCountdown > 0) {
        state = state.copyWith(preRaceCountdownValue: currentCountdown - 1);
      } else {
        debugPrint(
            '--- RaceNotifier: Countdown FINISHED. Stopping timer, setting race active. ---'); // <-- YENİ LOG
        timer.cancel();
        _preRaceCountdownTimer = null;
        // ÖNEMLİ: State'i güncellemeden önce mevcut state'i kontrol et
        if (state.isPreRaceCountdownActive) {
          // Hala geri sayım modundaysak
          state = state.copyWith(
              isPreRaceCountdownActive: false, isRaceActive: true);
          debugPrint(
              '--- RaceNotifier: State updated for actual race start. State: $state ---'); // <-- YENİ LOG
          _startActualRaceTracking(); // Geri sayım bitti, asıl takibi başlat
        } else {
          debugPrint(
              '--- RaceNotifier: Countdown finished, but state says countdown was already inactive? State: $state ---'); // <-- YENİ LOG
        }
      }
    });
  }

  void _startActualRaceTracking() async {
    debugPrint(
        '--- RaceNotifier: _startActualRaceTracking CALLED --- State: $state'); // <-- YENİ LOG
    state = state.copyWith(raceStartTime: DateTime.now());

    _listenToSignalREvents();
    _initializeRaceTimer();
    // Kalori hesaplama timer'ını başlat (veya _raceTimerTimer içine entegre et)
    _initializeCalorieCalculation(); // <-- Yeni metod çağrısı

    if (!state.isIndoorRace) {
      _initializeAntiCheatSystem();
    }
    
    // iOS için özel gecikme stratejisi
    if (Platform.isIOS) {
      debugPrint('RaceNotifier: iOS için özel başlatma stratejisi uygulanıyor...');
      
      // HealthKit bağlantısı için kısa bir gecikme
      // SignalR ve diğer işlemlerin tamamlanması için bekleyelim
      Future.delayed(const Duration(milliseconds: 300), () {
        debugPrint('RaceNotifier: iOS - İlk pedometer başlatma denemesi');
        if (state.hasPedometerPermission) {
          _initPedometer();
        }
      });
      
      // Yedek olarak belirli bir süre sonra tekrar deneyelim (bazı cihazlarda gerekebilir)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (state.isRaceActive && state.initialSteps == 0 && state.hasPedometerPermission) {
          debugPrint('RaceNotifier: iOS - İkinci pedometer başlatma denemesi');
          _initPedometer();
        }
      });
      
      // Konum izinleri varsa ve iç mekan yarışı değilse konum takibini başlat
      if (state.hasLocationPermission && !state.isIndoorRace) {
        // Konum için daha uzun bir gecikme kullanalım - iOS'ta kilit ekranı için önemli
        Future.delayed(const Duration(milliseconds: 500), () {
          _startLocationUpdates();
          
          // Belirli aralıklarla konum başlatmayı tekrar dene
          // Bu, bazı iOS cihazlarında konum takibinin kilitleme/uygulama değişiminden sonra düzgün çalışmasını sağlar
          _schedulePeriodicLocationCheck();
        });
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
      debugPrint('RaceNotifier: Yarış bitti eventi alındı.');
      _handleRaceEnd();
    });
    // Diğer SignalR eventleri (userJoined, userLeft) UI tarafından dinlenebilir veya burada ele alınabilir.
  }

  void _handleRaceEnd() async {
    // Prevent running if already finished
    if (state.isRaceFinished || !state.isRaceActive) {
      debugPrint(
          'RaceNotifier: _handleRaceEnd called but race already finished or inactive. Skipping.');
      return;
    }
    debugPrint('RaceNotifier: Yarış sona erdi, temizleme yapılıyor.');
    // Cleanup resources first
    await _cleanup();

    // Now update the state to indicate the race is finished normally
    state = state.copyWith(
      isRaceActive: false,
      isRaceFinished: true, // Set the finished flag
      remainingTime: Duration.zero, // Ensure remaining time is zero
    );
    debugPrint('RaceNotifier: State updated after race end: $state');

    // Yarışın bittiğini state'de işaretleyebiliriz ama cleanup direkt her şeyi durduracak
    // state = state.copyWith(isRaceActive: false); // Örneğin
    // Yarış bittiğinde UI'ın ne yapacağına karar vermek için state'e bir flag eklenebilir
    // Veya RaceScreen bu durumu kontrol edip FinishRaceScreen'e geçebilir.
    // Şimdilik state'i resetlemiyoruz, leaderboard görünsün diye.
    // state = state.copyWith(isRaceActive: false); // sadece aktifliği kapat
  }

  void _initializeRaceTimer() {
    _raceTimerTimer?.cancel();
    if (state.raceDuration == null) return;
    state = state.copyWith(remainingTime: state.raceDuration!);
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
        debugPrint('RaceNotifier: Yarış süresi doldu.');
        // _handleRaceEnd(); // Optional: End race here too
      }
    });
  }

  // Kalori Hesaplama Başlatma
  void _initializeCalorieCalculation() {
    _calorieCalculationTimer?.cancel();
    // Her 5 saniyede bir hesapla
    _calorieCalculationTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!state.isRaceActive) {
        timer.cancel();
        _calorieCalculationTimer = null;
        return;
      }
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
      // state = state.copyWith(currentCalories: 0); // Zaten başlangıçta 0
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

    // --- Geliştirilmiş Kalori Hesaplama Başlangıcı ---

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
      debugPrint(
          'Calorie Calc - User Data: Weight=$weightKg, Height=$heightCm, Age=$ageYears, Gender=$gender');
    } else {
      debugPrint('Calorie Calc - Using default user data.');
    }

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
    debugPrint(
        'Calorie Calc - Calculated BMR (per day): ${bmr.toStringAsFixed(2)}');

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
          cadence = stepsDifference / elapsedSeconds.toDouble();
        }
        debugPrint(
            'Calorie Calc (Indoor) - Cadence: ${cadence.toStringAsFixed(1)} steps/min');

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
        debugPrint(
            'Calorie Calc (Indoor) - Determined MET: $metValue based on Cadence');
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
        debugPrint(
            'Calorie Calc (Outdoor) - Determined MET: $metValue based on Pace: ${currentPaceKmH.toStringAsFixed(2)} km/h');
      }
    }
    //debugPrint('Calorie Calc - Determined MET: $metValue based on Pace: ${currentPaceKmH.toStringAsFixed(2)} km/h'); // Eski log yerine yukarıdakiler geldi

    // 4. Toplam Kaloriyi Hesapla (BMR * MET * Süre)
    // BMR günlük kalori, saniyeliğe çevirip MET ve süre ile çarp
    double bmrPerSecond = bmr / (24 * 60 * 60);
    int newCalories = (bmrPerSecond * elapsedSeconds * metValue).round();
    if (newCalories < 0) newCalories = 0;

    // --- Eski Hesaplama (Referans için) ---
    // double hours = elapsedSeconds / 3600.0;
    // int oldCalories = (weightKg * metValue * hours).round();
    // if (oldCalories < 0) oldCalories = 0;
    // --- Eski Hesaplama Sonu ---

    // --- Geliştirilmiş Kalori Hesaplama Sonu ---

    state =
        state.copyWith(currentCalories: state.currentCalories + newCalories);

    debugPrint(
        'RaceNotifier 🔥 Kalori hesaplandı (Yeni): +$newCalories kal (Toplam: ${state.currentCalories}) - BMR: ${bmr.toStringAsFixed(0)}, MET: $metValue, Hız: ${currentPaceKmH.toStringAsFixed(2)} km/h');

    // Son değerleri güncelle
    _lastCalorieCheckDistance = state.currentDistance;
    _lastCalorieCheckSteps = state.currentSteps;
    _lastCalorieCalculationTime = now;
  }

  void _initializeAntiCheatSystem() {
    // Hile Kontrolü - RaceScreen'den taşınacak
    // if (state.isIndoorRace) return; // <-- KALDIRILACAK

    _lastCheckDistance = state.currentDistance;
    _lastCheckSteps = state.currentSteps;
    _lastCheckTime = DateTime.now();
    state = state.copyWith(violationCount: 0);

    _antiCheatTimer?.cancel();

    // Yarış başladıktan 10 saniye sonra hile kontrolünü başlat
    Future.delayed(const Duration(seconds: 10), () {
      if (!state.isRaceActive) {
        debugPrint(
            'RaceNotifier: Anti-cheat system delay ended, but race is no longer active. Timer not started.');
        return;
      }

      debugPrint(
          'RaceNotifier: 10-second delay for anti-cheat system ended. Starting periodic checks.');
      _antiCheatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!state.isRaceActive) {
          timer.cancel();
          return;
        }
        _checkForCheating();
      });
    });
  }

  void _checkForCheating() {
    // Hile Kontrolü Mantığı - RaceScreen'den taşınacak
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
        debugPrint(
            'RaceNotifier 🔍 Hile kontrol $checkTypeLog: Cadence: ${cadence.toStringAsFixed(2)} steps/sec');
        if (cadence > maxRealisticCadence) {
          debugPrint(
              'RaceNotifier ❌ Hile ihlali $checkTypeLog: Aşırı yüksek kadans tespit edildi!');
          violation = true;
        }
      } else {
        debugPrint(
            'RaceNotifier 🔍 Hile kontrol $checkTypeLog: No steps or time elapsed for cadence check.');
      }
      // =======================================
    } else {
      // === SADECE OUTDOOR KONTROLÜ: MESAFE/ADIM ===
      checkTypeLog = "(Outdoor)";
      debugPrint(
          'RaceNotifier 🔍 Hile kontrol $checkTypeLog: $elapsedSeconds sn -> ${distanceDifference.toStringAsFixed(1)} m, $stepsDifference adım');
      // 1. Aşırı Hız Kontrolü
      if (distanceDifference > 250) {
        // 30 sn'de > 250m (~30 km/h)
        debugPrint(
            'RaceNotifier ❌ Hile ihlali $checkTypeLog: Aşırı yüksek hız tespit edildi!');
        violation = true;
      }
      // 2. Adım-Mesafe Tutarlılık Kontrolü (Sadece anlamlı mesafe varsa)
      else if (distanceDifference > 0) {
        final requiredMinSteps = distanceDifference * 0.5;
        if (stepsDifference < requiredMinSteps) {
          debugPrint(
              'RaceNotifier ❌ Hile ihlali $checkTypeLog: Adım-mesafe tutarsızlığı tespit edildi! ($stepsDifference adım < ${requiredMinSteps.toStringAsFixed(1)} gerekli)');
          violation = true;
        }
      }
    }

    // **** ORTAK İHLAL YÖNETİMİ ****
    if (violation) {
      final newViolationCount = state.violationCount + 1;
      // state = state.copyWith(violationCount: newViolationCount); // Update state later based on count
      debugPrint(
          'RaceNotifier ❌ Hile ihlali tespit edildi: $newViolationCount');

      if (newViolationCount == 1) {
        // First violation: Set flag to show warning
        debugPrint(
            'RaceNotifier: First cheat violation detected. Setting warning flag.');
        state = state.copyWith(
            violationCount: newViolationCount, showFirstCheatWarning: true);
        // Do not kick yet
      } else if (newViolationCount >= 2) {
        // Second violation: Kick the user
        debugPrint('RaceNotifier: Hile limiti aşıldı, yarıştan atılıyor.');
        state = state.copyWith(
            violationCount: newViolationCount,
            showFirstCheatWarning: false, // Ensure warning flag is off
            errorMessage:
                'Anormal aktivite nedeniyle yarıştan çıkarıldınız.' // More specific message
            );
        leaveRace(); // Kick the user
      }
    } else {
      // Reset violation count if no violation detected in this check?
      // Or keep it accumulating? Current logic keeps it accumulating.
      // If reset is needed: state = state.copyWith(violationCount: 0);
    }

    _lastCheckDistance = state.currentDistance;
    _lastCheckSteps = state.currentSteps;
    _lastCheckTime = now;
  }

  void _initPedometer() {
    _stepCountSubscription?.cancel();
    state = state.copyWith(initialSteps: 0, currentSteps: 0); // Reset steps
    
    debugPrint('RaceNotifier: Pedometer başlatılıyor...');
    
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
      debugPrint('RaceNotifier: Pedometer başlatma hatası: $e');
      state = state.copyWith(
        errorMessage: 'Adım sayar başlatılırken bir hata oluştu. Lütfen tekrar deneyin.'
      );
    }
  }

  // iOS için özel pedometer başlatma metodu
  void _initPedometerIOS() {
    debugPrint('RaceNotifier: iOS için pedometer başlatılıyor...');
    
    // Daha kısa bekleme süresi ve daha agresif retry stratejisi
    // Apple HealthKit'i uyandırmak için bazı cihazlarda daha fazla bekleme gerekebilir
    Future.delayed(const Duration(milliseconds: 50), () {
      // İlk başlatma denemesi
      _attemptStepCountListening(isFirstAttempt: true);
      
      // Farklı zamanlarda çoklu deneme - HealthKit bazen gecikmeli yanıt verebiliyor
      Future.delayed(const Duration(seconds: 1), () {
        if (state.isRaceActive && state.initialSteps == 0) {
          debugPrint('RaceNotifier: [iOS] 1-saniye kontrolü - adım yok, tekrar deneniyor...');
          _attemptStepCountListening(retryCount: 1);
        }
      });
      
      Future.delayed(const Duration(seconds: 3), () {
        if (state.isRaceActive && state.initialSteps == 0) {
          debugPrint('RaceNotifier: [iOS] 3-saniye kontrolü - adım yok, tekrar deneniyor...');
          _attemptStepCountListening(retryCount: 2);
        }
      });
      
      Future.delayed(const Duration(seconds: 7), () {
        if (state.isRaceActive && state.initialSteps == 0) {
          debugPrint('RaceNotifier: [iOS] 7-saniye kontrolü - adım yok, son deneme...');
          _attemptStepCountListening(retryCount: 3);
          
          // Kullanıcıya bilgi vermek için state'i güncelle
          if (state.initialSteps == 0) {
            state = state.copyWith(
              // Manuel başlatma için adım 1'den başlat
              initialSteps: 1,
              currentSteps: 0,
              errorMessage: 'Adım verileri almakta zorluk yaşıyoruz. Apple Health uygulamasını açıp adım erişimini onayladığınızdan emin olun.'
            );
          }
        }
      });
    });
  }
  
  // Tekrar kullanılabilir step count dinleme metodu - iOS için
  void _attemptStepCountListening({int retryCount = 0, bool isFirstAttempt = false}) {
    // Eğer önceki bir subscription varsa iptal et
    if (retryCount > 0) {
      _stepCountSubscription?.cancel();
    }
    
    try {
      debugPrint('RaceNotifier: [iOS] Adım dinleme #$retryCount başlıyor...');
      
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          final int stepValue = event.steps;
          debugPrint('RaceNotifier: [iOS] Adım olayı alındı (#$retryCount): $stepValue');
          
          if (!state.isRaceActive) {
            debugPrint('RaceNotifier: [iOS] Adım alındı, ancak yarış aktif değil');
            return;
          }
          
          // Eğer initialSteps henüz ayarlanmamışsa
          if (state.initialSteps == 0 && stepValue > 0) {
            debugPrint('RaceNotifier: [iOS] Başlangıç adımları ayarlanıyor: $stepValue');
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
              debugPrint('RaceNotifier: [iOS] Adım güncellendi (#$retryCount): $calculatedSteps (Ham: $stepValue - Başlangıç: ${state.initialSteps})');
              
              // Adımlar değişti, sunucuya bildir
              _updateLocation();
            }
          }
        },
        onError: (error) {
          debugPrint('RaceNotifier: [iOS] Adım hatası (#$retryCount): $error');
          
          // İlk denemede veya retry 1'de hata mesajı gösterme, diğerlerinde göster
          if (retryCount >= 2) {
            state = state.copyWith(
              errorMessage: 'Adım verisi alınamıyor. Apple Health iznini kontrol edin.'
            );
          }
        },
        cancelOnError: false, // Hatalarda otomatik iptal etme
      );
    } catch (e) {
      debugPrint('RaceNotifier: [iOS] Adım dinleme başlatma hatası (#$retryCount): $e');
      if (retryCount >= 2) {
        state = state.copyWith(
          errorMessage: 'Adım ölçüm başlatılamadı. iOS Health ayarlarını kontrol edin.'
        );
      }
    }
  }

  // Android için pedometer başlatma metodu
  void _initPedometerAndroid() {
    debugPrint('RaceNotifier: Android için pedometer başlatılıyor...');
    
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        debugPrint('RaceNotifier: [Android] Adım olayı alındı: ${event.steps}');
        
        if (!state.isRaceActive) {
          debugPrint('RaceNotifier: [Android] Adım alındı, ancak yarış aktif değil');
          return;
        }

        // İlk adım sayısını kaydet
        if (state.initialSteps == 0) {
          state = state.copyWith(
            initialSteps: event.steps,
            currentSteps: 0
          );
          debugPrint('RaceNotifier: [Android] Başlangıç adımları ayarlandı: ${event.steps}');
          // İlk adımlar ayarlandı, sunucuya bildir
          _updateLocation();
        } else {
          // Adım farkını hesapla
          int calculatedSteps = event.steps - state.initialSteps;
          if (calculatedSteps < 0) calculatedSteps = 0;
          
          if (calculatedSteps != state.currentSteps) {
            state = state.copyWith(currentSteps: calculatedSteps);
            debugPrint('RaceNotifier: [Android] Adım güncellendi: $calculatedSteps');
            // Adım değişti, sunucuya bildir
            _updateLocation();
          }
        }
      },
      onError: (error) {
        debugPrint('RaceNotifier: [Android] Adım sayar hatası: $error');
        state = state.copyWith(
          errorMessage: 'Adım verisi alınamıyor. Uygulama izinlerini kontrol edin.'
        );
        
        // Android için tekrar deneme
        if (state.isRaceActive && state.initialSteps == 0) {
          debugPrint('RaceNotifier: [Android] Pedometer tekrar deneniyor...');
          
          _stepCountSubscription?.cancel();
          Future.delayed(const Duration(seconds: 1), () {
            _initPedometerAndroid(); // Tekrar başlatmayı dene
          });
        }
      },
      cancelOnError: false,
    );
  }

  void _startLocationUpdates() {
    debugPrint(
        '--- RaceNotifier: _startLocationUpdates CALLED ---'); // Log start of function
    if (state.isIndoorRace ||
        !state.hasLocationPermission ||
        !state.isRaceActive) {
      debugPrint(
          '--- RaceNotifier: _startLocationUpdates - Conditions check failed (indoor/perm/active). Returning. ---');
      return;
    }
    _positionStreamSubscription?.cancel();

    // iOS için ekstra kontrol - konum servislerinin açık olduğundan emin ol
    if (Platform.isIOS) {
      // iOS native konum takibini etkinleştir
      _enableIOSNativeLocationTracking();
      
      Geolocator.isLocationServiceEnabled().then((serviceEnabled) {
        if (!serviceEnabled) {
          debugPrint('RaceNotifier: iOS konum servisleri kapalı! Konum takibi başlatılamıyor.');
          state = state.copyWith(
            errorMessage: 'Konum servisleri kapalı, konum takibi yapılamıyor.'
          );
          return;
        }
        
        // Servisler açıksa izni kontrol et
        Geolocator.checkPermission().then((permission) {
          if (permission != LocationPermission.always && 
              permission != LocationPermission.whileInUse) {
            debugPrint('RaceNotifier: iOS konum izni yok! Konum takibi başlatılamıyor.');
            state = state.copyWith(
              errorMessage: 'Konum izni yok, konum takibi yapılamıyor.'
            );
            return;
          }
          
          // Hem servisler açık hem de izin varsa konum takibini başlat
          _initializeLocationStream();
        });
      });
    } else {
      // Android için direk başlat
      _initializeLocationStream();
    }
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
      // iOS için özel arka plan modu etkinleştirme
      _setIOSBackgroundLocationActive();
      
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
    debugPrint(
        '--- RaceNotifier: About to call Geolocator.getPositionStream... ---'); // Log before stream
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      debugPrint(
          '--- RaceNotifier: Received position update from stream. Latitude: ${position.latitude} ---'); // Log inside stream listen
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
    }, onError: (error) {
      debugPrint('RaceNotifier Konum Takibi Hatası: $error');
      
    });
  }

  // iOS arka plan konum modunu etkinleştir
  void _setIOSBackgroundLocationActive() {
    if (!Platform.isIOS) return;
    
    try {
      // iOS'un CLLocationManager arka plan modu için ek ayarlar
      // Bu metod Geolocator paketinin önerdiği çözümü uyguluyor
      debugPrint('RaceNotifier: iOS için arka plan konum modu etkinleştiriliyor...');
      
      // iOS 14.0'dan sonra background izni kontrolü yapalım
      Geolocator.checkPermission().then((permission) {
        if (permission == LocationPermission.always) {
          debugPrint('RaceNotifier: iOS konum izni ALWAYS, arka plan modu aktif edilebilir.');
          
          // iOS'un arka plan modu için sistemdeki "significant-change" servisi etkinleştirilmeli
          // Bu, enerji tasarrufu için iOS'un konum güncellemelerini optimize etmesini sağlar
          Geolocator.getServiceStatusStream().listen((status) {
            debugPrint('RaceNotifier: iOS konum servis durumu değişti: $status');
          });
          
          // Kilit ekranında konum takibi için lokasyon takibinin zaten aktif olduğundan emin olalım
          Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).then((position) {
            debugPrint('RaceNotifier: iOS mevcut konum alındı, konum servisleri aktif.');
          }).catchError((e) {
            debugPrint('RaceNotifier: iOS mevcut konum alınırken hata: $e');
          });
        } else {
          debugPrint('RaceNotifier: iOS konum izni: $permission, arka plan konum takibi için "Her Zaman" seçili olmalı.');
        }
      });
    } catch (e) {
      debugPrint('RaceNotifier: iOS arka plan konum modu etkinleştirme hatası: $e');
    }
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
      debugPrint(
          'RaceNotifier 📊 Konum güncellendi -> Mesafe: ${distanceToSend.toStringAsFixed(2)} km, Adım: ${state.currentSteps}, Kalori: ${state.currentCalories}');
    } catch (e) {
      debugPrint('RaceNotifier ❌ Konum güncellemesi gönderilirken hata: $e');
    }
  }

  Future<void> _cleanup() async {
    debugPrint('RaceNotifier: Kaynaklar temizleniyor...');
    _preRaceCountdownTimer?.cancel();
    _raceTimerTimer?.cancel();
    _antiCheatTimer?.cancel();
    _calorieCalculationTimer?.cancel(); // Kalori timer'ını da iptal et
    _locationCheckTimer?.cancel(); // iOS periyodik konum kontrol timer'ı
    _positionStreamSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _raceEndedSubscription?.cancel();

    _preRaceCountdownTimer = null;
    _raceTimerTimer = null;
    _antiCheatTimer = null;
    _calorieCalculationTimer = null;
    _locationCheckTimer = null; // Timer referansını null yap
    _positionStreamSubscription = null;
    _stepCountSubscription = null;
    _leaderboardSubscription = null;
    _raceEndedSubscription = null;
    
    // iOS için özel temizleme işlemleri
    if (Platform.isIOS) {
      // Bildirimler
      await _cancelIOSNotification();
      
      // Native konum takibi
      await _disableIOSNativeLocationTracking();
    }
  }

  // iOS için bildirim gösterme ve yönetme metodları
  Future<void> _initializeNotifications() async {
    if (_isNotificationInitialized) return;
    
    // iOS bildirimleri için
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false, // İzinleri zaten başka yerde istiyoruz
    );
    
    // Android bildirimleri için (zaten ForegroundNotificationConfig'i kullanıyoruz, ama yine de ayarlayalım)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('launcher_icon');
    
    // Uygulama için bildirim ayarlarını initialize et
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    try {
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      _isNotificationInitialized = true;
      debugPrint('RaceNotifier: Bildirimler başarıyla başlatıldı.');
    } catch (e) {
      debugPrint('RaceNotifier: Bildirim başlatma hatası: $e');
    }
  }
  
  // iOS için bildirim gösterme
  Future<void> _showIOSNotification(String title, String body) async {
    if (!Platform.isIOS) return;
    
    // Bildirimleri başlat
    await _initializeNotifications();
    
    // iOS için bildirim detayları
    const DarwinNotificationDetails iOSNotificationDetails = DarwinNotificationDetails(
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
      debugPrint('RaceNotifier: iOS bildirimi gösterildi: $title, $body');
    } catch (e) {
      debugPrint('RaceNotifier: iOS bildirim gösterme hatası: $e');
    }
  }
  
  // iOS için bildirimi iptal etme
  Future<void> _cancelIOSNotification() async {
    if (!Platform.isIOS || !_isNotificationInitialized) return;
    
    try {
      await flutterLocalNotificationsPlugin.cancel(1); // ID:1 ile gösterilen bildirimi iptal et
      debugPrint('RaceNotifier: iOS bildirimi iptal edildi.');
    } catch (e) {
      debugPrint('RaceNotifier: iOS bildirim iptal hatası: $e');
    }
  }

  // --- Yeni Metod: İlk Hile Uyarısını Kapatma ---
  void dismissFirstCheatWarning() {
    if (state.showFirstCheatWarning) {
      debugPrint('RaceNotifier: Dismissing first cheat warning.');
      // --- DEĞİŞİKLİK: Uyarıyı kapatırken yarışın bitip bitmediğini kontrol et ---
      final bool raceActuallyFinished =
          state.isRaceActive && state.remainingTime <= Duration.zero;
      if (raceActuallyFinished) {
        debugPrint(
            'RaceNotifier: Warning dismissed, but race had already finished. Triggering race end.');
        // Uyarıyı kapat ve yarışı bitir
        state = state.copyWith(showFirstCheatWarning: false);
        _handleRaceEnd(); // Yarış bitirme mantığını tetikle
      } else {
        // Sadece uyarıyı kapat
        state = state.copyWith(showFirstCheatWarning: false);
      }
      // --- DEĞİŞİKLİK SONU ---
    }
  }

  // iOS için periyodik konum kontrolü zamanla
  Timer? _locationCheckTimer;
  
  void _schedulePeriodicLocationCheck() {
    // Önceki timer varsa iptal et
    _locationCheckTimer?.cancel();
    
    // Her 15 saniyede bir konum takibini kontrol et/yenile - daha sık kontrol et
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!state.isRaceActive) {
        timer.cancel();
        _locationCheckTimer = null;
        return;
      }
      
      if (Platform.isIOS && !state.isIndoorRace && state.hasLocationPermission) {
        debugPrint('RaceNotifier: iOS periyodik konum kontrolü yapılıyor...');
        
        // Native konum takibini tekrar etkinleştir
        _enableIOSNativeLocationTracking();
        
        // Mevcut konum durumunu kontrol et
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5)
        ).then((position) {
          debugPrint('RaceNotifier: iOS periyodik konum kontrolü başarılı: ${position.latitude}, ${position.longitude}');
          
          // Eğer positionStream dinleyicisi null ise yeniden başlat
          if (_positionStreamSubscription == null) {
            debugPrint('RaceNotifier: iOS konum dinleyicisi null, yeniden başlatılıyor...');
            _startLocationUpdates();
          } else {
            // Stream var ama yine de mevcut konum alabiliyoruz, güncellemeleri kontrol et
            debugPrint('RaceNotifier: Konum stream mevcut, güncelleniyor...');
            _startLocationUpdates();
          }
        }).catchError((e) {
          debugPrint('RaceNotifier: iOS periyodik konum kontrolü hatası: $e');
          // Hata olursa konum takibini yeniden başlatmaya çalış
          _startLocationUpdates();
        });
      }
    });
  }

  // iOS için native konum takibini etkinleştirme metodları
  static const _platformChannelLocation = MethodChannel('com.movliq/location');
  
  Future<void> _enableIOSNativeLocationTracking() async {
    if (!Platform.isIOS) return;
    
    try {
      debugPrint('RaceNotifier: iOS native konum takibi etkinleştiriliyor...');
      await _platformChannelLocation.invokeMethod('enableBackgroundLocationTracking');
      debugPrint('RaceNotifier: iOS native konum takibi başarıyla etkinleştirildi.');
      
      // 5 saniye sonra konum izlemesinin hala aktif olduğunu kontrol et
      Future.delayed(const Duration(seconds: 5), () {
        if (state.isRaceActive && !state.isIndoorRace && Platform.isIOS) {
          _checkLocationTrackingStatus();
        }
      });
    } catch (e) {
      debugPrint('RaceNotifier: iOS native konum takibi etkinleştirme hatası: $e');
    }
  }
  
  Future<void> _disableIOSNativeLocationTracking() async {
    if (!Platform.isIOS) return;
    
    try {
      debugPrint('RaceNotifier: iOS native konum takibi devre dışı bırakılıyor...');
      await _platformChannelLocation.invokeMethod('disableBackgroundLocationTracking');
      debugPrint('RaceNotifier: iOS native konum takibi başarıyla devre dışı bırakıldı.');
    } catch (e) {
      debugPrint('RaceNotifier: iOS native konum takibi devre dışı bırakma hatası: $e');
    }
  }
  
  // Yeni: Konum takibi durumunu kontrol et
  Future<void> _checkLocationTrackingStatus() async {
    if (!Platform.isIOS || !state.isRaceActive || state.isIndoorRace) return;
    
    // Daha agresif bir yaklaşım - konum iznine ve servislerin açık olduğuna bakıp
    // gerekirse location stream'i yeniden oluştur
    try {
      bool servicesEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      debugPrint('RaceNotifier: iOS konum takibi durumu kontrol ediliyor... '
          'Servisler: ${servicesEnabled ? 'Aktif' : 'Kapalı'}, '
          'İzin: $permission');
      
      if (!servicesEnabled) {
        debugPrint('RaceNotifier: Konum servisleri kapalı, konum takibi yapılamıyor!');
        return;
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('RaceNotifier: Konum izni verilmemiş, konum takibi yapılamıyor!');
        return;
      }
      
      // Eğer hala buradaysak, izin ve servisler tamam demektir
      // Stream'i yeniden başlat
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
      
      // Kısa bir gecikme ekleyip stream'i yeniden oluştur
      Future.delayed(const Duration(milliseconds: 500), () {
        if (state.isRaceActive && !state.isIndoorRace) {
          _startLocationUpdates();
        }
      });
    } catch (e) {
      debugPrint('RaceNotifier: Konum takip durumu kontrolü hatası: $e');
    }
  }
}
