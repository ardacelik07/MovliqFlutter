import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'; // debugPrint için
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_flutter_project/core/services/signalr_service.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/race_state.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/user_data_provider.dart'; // UserDataProvider importu
import 'package:my_flutter_project/features/auth/domain/models/user_data_model.dart'; // UserDataModel importu

part 'race_provider.g.dart';

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
          '--- RaceNotifier: Aktif yarış zaten var, startRace engellendi. Current state: $state'); // <-- YENİ LOG
      return;
    }

    debugPrint(
        'RaceNotifier: Yarış başlatılıyor... (İzinler kontrol ediliyor)'); // Mevcut log güncellendi

    // İzinleri kontrol et (UI'dan bağımsız kontrol)
    final hasLocation = await _checkPermission(Permission.locationAlways);
    final hasActivity = await _checkPermission(Platform.isAndroid
        ? Permission.activityRecognition
        : Permission.sensors);
    debugPrint(
        '--- RaceNotifier: İzinler kontrol edildi - Location: $hasLocation, Activity: $hasActivity ---'); // <-- YENİ LOG

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
    final status = await permission.status;
    return status.isGranted || status.isLimited;
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
    if (state.hasPedometerPermission) {
      _initPedometer();
    }
    if (state.hasLocationPermission && !state.isIndoorRace) {
      _startLocationUpdates();
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
          cadence = stepsDifference * (60 / elapsedSeconds);
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
    if (state.isIndoorRace) return;

    _lastCheckDistance = state.currentDistance;
    _lastCheckSteps = state.currentSteps;
    _lastCheckTime = DateTime.now();
    state = state.copyWith(violationCount: 0); // Başlangıçta ihlal yok

    _antiCheatTimer?.cancel();
    _antiCheatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!state.isRaceActive) {
        timer.cancel();
        return;
      }
      _checkForCheating();
    });
  }

  void _checkForCheating() {
    // Hile Kontrolü Mantığı - RaceScreen'den taşınacak
    if (_lastCheckTime == null || !state.isRaceActive) return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastCheckTime!).inSeconds;
    if (elapsedSeconds < 25) return;

    final distanceDifference =
        (state.currentDistance - _lastCheckDistance) * 1000; // m
    final stepsDifference = state.currentSteps - _lastCheckSteps;

    debugPrint(
        'RaceNotifier 🔍 Hile kontrol: $elapsedSeconds sn -> $distanceDifference m, $stepsDifference adım');

    bool violation = false;
    if (distanceDifference > 250) {
      // 30 sn'de > 250m
      violation = true;
    } else if (distanceDifference > 0) {
      final requiredMinSteps = distanceDifference * 0.5;
      if (stepsDifference < requiredMinSteps) {
        violation = true;
      }
    }

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

    _stepCountSubscription =
        Pedometer.stepCountStream.listen((StepCount event) {
      if (!state.isRaceActive) return;

      int currentInitialSteps = state.initialSteps;
      if (currentInitialSteps == 0) {
        currentInitialSteps = event.steps;
        state =
            state.copyWith(initialSteps: currentInitialSteps, currentSteps: 0);
      } else {
        int newSteps = event.steps - currentInitialSteps;
        if (newSteps >= state.currentSteps) {
          // Adım azalmadıysa
          state = state.copyWith(currentSteps: newSteps);
          _updateLocation(); // Adım değiştiğinde sunucuya bildir
        }
      }
    }, onError: (error) {
      debugPrint('RaceNotifier Adım Sayar Hatası: $error');
      state = state.copyWith(errorMessage: 'Adım sayar okunamadı.');
    });
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
      );
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
      state = state.copyWith(errorMessage: 'Konum bilgisi alınamadı.');
    });
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
    _positionStreamSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _raceEndedSubscription?.cancel();

    _preRaceCountdownTimer = null;
    _raceTimerTimer = null;
    _antiCheatTimer = null;
    _calorieCalculationTimer = null;
    _positionStreamSubscription = null;
    _stepCountSubscription = null;
    _leaderboardSubscription = null;
    _raceEndedSubscription = null;
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
}
