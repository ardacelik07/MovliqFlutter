import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/race_service_channel.dart'; // Platform kanalı sınıfı
import '../../../../features/auth/domain/models/race_state.dart'; // RaceState sınıfı
import 'dart:developer'; // log fonksiyonu için

final raceProvider = StateNotifierProvider<RaceNotifier, RaceState>((ref) {
  // ref'i Notifier'a verelim
  return RaceNotifier(ref);
});

class RaceNotifier extends StateNotifier<RaceState> {
  final Ref _ref;
  StreamSubscription? _raceUpdateSubscription;

  RaceNotifier(this._ref) : super(const RaceState()) {
    // Constructor'da DEĞİL, startRace içinde başlatıyoruz
  }

  // Yarışı başlat
  Future<void> startRace({
    Duration? duration,
    required int roomId,
  }) async {
    if (state.status == RaceStatus.running ||
        state.status == RaceStatus.starting) {
      log('Race already running or starting, ignoring start command.',
          name: 'RaceNotifier');
      return;
    }

    log('Starting race with roomId: $roomId, duration: $duration',
        name: 'RaceNotifier');
    state = state.copyWith(
        status: RaceStatus.starting, errorMessage: null, forceErrorNull: true);

    try {
      // Dinleyiciyi burada (tekrar) başlatalım, yarış başlamadan önce hazır olsun
      _listenToRaceUpdates();

      await RaceServiceChannel.startRaceService(
        duration: duration,
        roomId: roomId,
      );
      log('startRaceService method channel call successful.',
          name: 'RaceNotifier');
      // Durumu hemen running yapmıyoruz, ilk event'i bekliyoruz
    } catch (e) {
      log('Error starting race service', error: e, name: 'RaceNotifier');
      state = state.copyWith(
          status: RaceStatus.error, errorMessage: "Servis başlatılamadı: $e");
    }
  }

  // Yarışı durdur
  Future<void> stopRace() async {
    log('Stopping race...', name: 'RaceNotifier');
    if (state.status != RaceStatus.running &&
        state.status != RaceStatus.paused) {
      log('Race not running or paused, ignoring stop command.',
          name: 'RaceNotifier');
      return;
    }

    // Önce dinleyiciyi iptal et
    _raceUpdateSubscription?.cancel();
    _raceUpdateSubscription = null; // Referansı temizle
    log('Race update subscription cancelled.', name: 'RaceNotifier');

    try {
      await RaceServiceChannel.stopRaceService();
      log('stopRaceService method channel call successful.',
          name: 'RaceNotifier');
      // State'i sıfırla (stopRace çağrıldığı için idle yapalım)
      state = const RaceState();
      log('Race state reset to idle.', name: 'RaceNotifier');
    } catch (e) {
      log('Error stopping race service', error: e, name: 'RaceNotifier');
      // Durdurma hatası olsa bile state'i sıfırla
      // !!! const KULLANILMAZ !!!
      state = RaceState(
          status: RaceStatus.error, errorMessage: "Servis durdurulamadı: $e");
    }
  }

  // Servisten gelen güncellemeleri dinle
  void _listenToRaceUpdates() {
    // Zaten bir abonelik varsa tekrar oluşturma
    if (_raceUpdateSubscription != null) {
      log('Already listening to race updates.', name: 'RaceNotifier');
      return;
    }
    log('Subscribing to race updates stream...', name: 'RaceNotifier');
    _raceUpdateSubscription = RaceServiceChannel.raceUpdateStream.listen(
      (data) {
        log("Received data MAP: $data", name: 'RaceNotifier');
        bool isLeaderboardUpdate = false;
        bool isStatusUpdate = false;

        RaceState newState = state; // Başlangıç olarak mevcut state'i al

        // Liderlik tablosunu işle
        if (data.containsKey('leaderboard') && data['leaderboard'] is List) {
          log("Processing leaderboard update...", name: 'RaceNotifier');
          isLeaderboardUpdate = true;
          try {
            final List<dynamic> rawLeaderboard =
                data['leaderboard'] as List<dynamic>;
            final List<RaceParticipant> parsedLeaderboard = rawLeaderboard
                .map((item) =>
                    RaceParticipant.fromJson(item as Map<String, dynamic>))
                .toList();
            newState = newState.copyWith(leaderboard: parsedLeaderboard);
            log("Leaderboard updated in temp state with ${parsedLeaderboard.length} participants.",
                name: 'RaceNotifier');
          } catch (e) {
            log("Error parsing leaderboard data",
                error: e, name: 'RaceNotifier');
            // Hata durumunda liderlik tablosu güncellenmez
          }
        }

        // Durum verisini işle
        final newStatusString = data['status'] as String?;
        RaceStatus parsedStatus = newState.status; // Önceki durumu koru

        if (newStatusString != null) {
          log("Received status string: $newStatusString", name: 'RaceNotifier');
          isStatusUpdate = true;
          parsedStatus = RaceStatus.values.firstWhere(
            (e) => e.name == newStatusString,
            orElse: () {
              log("Unknown status string '$newStatusString'. Keeping old status: ${newState.status}",
                  name: 'RaceNotifier');
              return newState.status; // Bilinmiyorsa mevcutu koru
            },
          );
          log("Parsed status: $parsedStatus", name: 'RaceNotifier');
        }

        // Yeni state'i oluştur (status ve diğer alanlar)
        if (isStatusUpdate || isLeaderboardUpdate) {
          // Eğer status veya leaderboard güncellendiyse
          if (parsedStatus == RaceStatus.error) {
            final errorMessage =
                data['error'] as String? ?? "Bilinmeyen servis hatası";
            log("Setting state to ERROR: $errorMessage", name: 'RaceNotifier');
            newState = newState.copyWith(
              status: RaceStatus.error,
              errorMessage: errorMessage,
            );
          } else if (parsedStatus == RaceStatus.stopped) {
            log("Setting state to STOPPED.", name: 'RaceNotifier');
            newState = newState.copyWith(
              status: RaceStatus.stopped,
              elapsedSeconds:
                  data['elapsedSeconds'] as int? ?? newState.elapsedSeconds,
              remainingSeconds: data['remainingSeconds'] as int?,
              distanceKm: data['distanceKm'] as double? ?? newState.distanceKm,
              steps: data['steps'] as int? ?? newState.steps,
              speedKmh: data['speedKmh'] as double? ?? newState.speedKmh,
              errorMessage: null,
              forceErrorNull: true,
            );
          } else {
            // running, paused veya idle (eğer status güncellenmediyse)
            log("Updating core metrics with status: $parsedStatus",
                name: 'RaceNotifier');
            newState = newState.copyWith(
              status: parsedStatus, // Gelen veya mevcut durum
              elapsedSeconds:
                  data['elapsedSeconds'] as int? ?? newState.elapsedSeconds,
              remainingSeconds: data['remainingSeconds'] as int?,
              forceRemainingNull: !data.containsKey('remainingSeconds'),
              distanceKm: data['distanceKm'] as double? ?? newState.distanceKm,
              steps: data['steps'] as int? ?? newState.steps,
              speedKmh: data['speedKmh'] as double? ?? newState.speedKmh,
              errorMessage: null,
              forceErrorNull: true,
            );
          }
        } else {
          log("No status or leaderboard update in this data packet.",
              name: 'RaceNotifier');
        }

        // Eğer durum 'starting' idi ve bir güncelleme (leaderboard veya status)
        // geldiyse ve yeni durum error/stopped DEĞİLSE, 'running' yap.
        if (state.status == RaceStatus.starting &&
            (isLeaderboardUpdate || isStatusUpdate)) {
          if (newState.status != RaceStatus.error &&
              newState.status != RaceStatus.stopped) {
            // Eğer gelen status zaten running/paused ise onu koru, değilse running yap
            final finalStatus = (newState.status == RaceStatus.running ||
                    newState.status == RaceStatus.paused)
                ? newState.status
                : RaceStatus.running;
            if (newState.status != finalStatus) {
              log("Transitioning from 'starting' to '$finalStatus' because first data received.",
                  name: 'RaceNotifier');
              newState = newState.copyWith(status: finalStatus);
            }
          }
        }

        // Sadece gerçekten bir değişiklik varsa state'i güncelle
        if (newState != state) {
          log("Updating state: Status=${newState.status}, LB=${newState.leaderboard.length}, Time=${newState.elapsedSeconds}, Dist=${newState.distanceKm.toStringAsFixed(2)}",
              name: 'RaceNotifier');
          state = newState;

          // Durdurulduysa aboneliği iptal et
          if (newState.status == RaceStatus.stopped) {
            _raceUpdateSubscription?.cancel();
            _raceUpdateSubscription = null; // Referansı temizle
            log("Unsubscribed from race updates because race stopped.",
                name: 'RaceNotifier');
          }
        } else {
          log("Received data did not result in a state change from previous.",
              name: 'RaceNotifier');
        }
      },
      onError: (error) {
        log("Race update stream error", error: error, name: 'RaceNotifier');
        state = state.copyWith(
          status: RaceStatus.error,
          errorMessage: "Servis bağlantı hatası: $error",
        );
        _raceUpdateSubscription?.cancel();
        _raceUpdateSubscription = null; // Referansı temizle
      },
      onDone: () {
        log("Race update stream done.", name: 'RaceNotifier');
        if (state.status == RaceStatus.running ||
            state.status == RaceStatus.paused) {
          log("Stream closed unexpectedly. Setting status to idle.",
              name: 'RaceNotifier');
          state = state.copyWith(status: RaceStatus.idle);
        }
        _raceUpdateSubscription = null; // Referansı temizle
      },
      cancelOnError: false,
    );
  }

  // Notifier dispose olduğunda aboneliği iptal et
  @override
  void dispose() {
    log("RaceNotifier disposing. Cancelling subscription if active.",
        name: 'RaceNotifier');
    _raceUpdateSubscription?.cancel();
    super.dispose();
  }
}
