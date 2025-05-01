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
import 'package:wakelock_plus/wakelock_plus.dart';

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

  @override
  RaceState build() {
    // Başlangıç durumu

    // --- TEMİZLEME ---
    // Notifier dispose olduğunda tüm kaynakları temizle
    ref.onDispose(() {
      debugPrint('RaceNotifier: Disposing - Cleaning up resources...');
      _cleanup();
    });
    // --- TEMİZLEME SONU ---

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
        '--- RaceNotifier: startRace CALLED --- Room: $roomId, Countdown: $countdownSeconds, Duration: $raceDurationMinutes, Indoor: $isIndoorRace, Email: $userEmail'); // <-- YENİ LOG

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
    );
    debugPrint(
        '--- RaceNotifier: Initial state SET --- State: $state'); // <-- YENİ LOG

    // Geri sayımı başlat
    _startPreRaceCountdown();
  }

  Future<void> leaveRace() async {
    debugPrint('RaceNotifier: Yarıştan ayrılınıyor...');
    await _cleanup(); // Tüm kaynakları temizle
    state = const RaceState(); // State'i başlangıç durumuna döndür

    // SignalR'dan da ayrıl
    try {
      final signalRService = ref.read(signalRServiceProvider);
      if (signalRService.isConnected && state.roomId != null) {
        // Yarış aktifken ayrılma veya normal ayrılma metodunu çağırabiliriz.
        // Şimdilik genel leaveRaceRoom kullanalım.
        await signalRService.leaveRaceRoom(state.roomId!); // roomId null olamaz
      }
    } catch (e) {
      debugPrint('RaceNotifier: SignalR odasından ayrılırken hata: $e');
    }
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
    debugPrint('RaceNotifier: Geri sayım bitti, asıl takip başlıyor...');
    await WakelockPlus.enable(); // Cihazın uyumasını engelle
    state = state.copyWith(raceStartTime: DateTime.now());

    // Liderlik tablosu ve yarış bitişini dinlemeye başla
    _listenToSignalREvents();

    // Yarış zamanlayıcısını başlat
    _initializeRaceTimer();

    // Hile kontrolünü başlat (indoor değilse)
    if (!state.isIndoorRace) {
      _initializeAntiCheatSystem();
    }

    // Adım sayar başlat (izin varsa)
    if (state.hasPedometerPermission) {
      _initPedometer();
    }

    // Konum takibini başlat (izin varsa ve indoor değilse)
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
    if (state.raceDuration == null) return; // Süre yoksa başlatma

    state = state.copyWith(
        remainingTime: state.raceDuration!); // Kalan süreyi başlangıçta ayarla

    _raceTimerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRaceActive) {
        timer.cancel();
        return;
      }

      if (state.remainingTime.inSeconds > 0) {
        state = state.copyWith(
            remainingTime: state.remainingTime - const Duration(seconds: 1));
      } else {
        // Süre bitti, SignalR'dan bitiş eventi gelmesini bekle
        // Ancak güvenlik önlemi olarak burada da yarışı bitirebiliriz.
        timer.cancel();
        _raceTimerTimer = null;
        debugPrint('RaceNotifier: Yarış süresi doldu.');
        // _handleRaceEnd(); // İsteğe bağlı olarak burada da sonlandırılabilir
      }
    });
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
      state = state.copyWith(violationCount: newViolationCount);
      debugPrint(
          'RaceNotifier ❌ Hile ihlali tespit edildi: $newViolationCount');
      if (newViolationCount >= 2) {
        debugPrint('RaceNotifier: Hile limiti aşıldı, yarıştan atılıyor.');
        // Kullanıcıyı atma işlemi burada tetiklenmeli (örn. leaveRace çağırılabilir)
        // Veya UI'a özel bir state gönderilebilir.
        state = state.copyWith(
            errorMessage: 'Hile limiti aşıldı.'); // Hata mesajı ekle
        leaveRace(); // Yarıştan çıkar
      } else {
        // İlk ihlalde UI'ı bilgilendirmek için state güncellenebilir
        // state = state.copyWith(showCheatWarning: true); gibi
      }
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
    if (state.isIndoorRace ||
        !state.hasLocationPermission ||
        !state.isRaceActive) {
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
          enableWakeLock: true,
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
      await signalRService.updateLocation(
          state.roomId!, distanceToSend, state.currentSteps);
      debugPrint(
          'RaceNotifier 📊 Konum güncellendi -> Mesafe: ${distanceToSend.toStringAsFixed(2)} km, Adım: ${state.currentSteps}');
    } catch (e) {
      debugPrint('RaceNotifier ❌ Konum güncellemesi gönderilirken hata: $e');
      // state = state.copyWith(errorMessage: 'Sunucuya konum gönderilemedi.'); // Çok sık hata mesajı vermemek için kapatılabilir
    }
  }

  Future<void> _cleanup() async {
    debugPrint('RaceNotifier: Kaynaklar temizleniyor...');
    _preRaceCountdownTimer?.cancel();
    _raceTimerTimer?.cancel();
    _antiCheatTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _raceEndedSubscription?.cancel();

    _preRaceCountdownTimer = null;
    _raceTimerTimer = null;
    _antiCheatTimer = null;
    _positionStreamSubscription = null;
    _stepCountSubscription = null;
    _leaderboardSubscription = null;
    _raceEndedSubscription = null;

    await WakelockPlus.disable(); // Wakelock'u kapat
  }
}
