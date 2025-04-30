import 'dart:async';
import 'dart:convert'; // jsonDecode için eklendi
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/race_service_channel.dart'; // Platform kanalı sınıfı
import '../../../../features/auth/domain/models/race_state.dart'; // RaceState sınıfı
import '../../../../core/services/storage_service.dart'; // StorageService için eklendi
import 'dart:developer'; // log fonksiyonu için

final raceProvider = StateNotifierProvider<RaceNotifier, RaceState>((ref) {
  // ref'i Notifier'a verelim
  return RaceNotifier(ref);
});

class RaceNotifier extends StateNotifier<RaceState> {
  final Ref _ref;
  StreamSubscription? _raceUpdateSubscription;
  bool _isDisposed = false; // Dispose bayrağı eklendi

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
      // Önce token'ı al
      log('Fetching token...', name: 'RaceNotifier');
      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        log('Token not found in storage.', name: 'RaceNotifier');
        throw Exception('Kimlik doğrulama bilgisi bulunamadı (Provider)');
      }
      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];
      log('Token fetched successfully.', name: 'RaceNotifier');

      // Dinleyiciyi burada (tekrar) başlatalım, yarış başlamadan önce hazır olsun
      _listenToRaceUpdates();

      // Native servisi token ile başlat
      await RaceServiceChannel.startRaceService(
        duration: duration,
        roomId: roomId,
        token: token, // Token'ı parametre olarak gönder
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
        // !!!!!!! DISPOSED KONTROLÜ - EN BAŞA ALINDI !!!!!!!
        if (_isDisposed) {
          log("Notifier disposed, ignoring incoming data.",
              name: 'RaceNotifier');
          return; // Dispose edildiyse veri işleme
        }

        log("Received data MAP: $data", name: 'RaceNotifier');

        // --- YENİ BASİTLEŞTİRİLMİŞ MANTIK ---

        RaceState newState = state; // Başlangıç olarak mevcut state'i al

        // 1. Liderlik tablosunu parse et (varsa)
        List<RaceParticipant> parsedLeaderboard =
            newState.leaderboard; // Önceki listeyi koru
        if (data.containsKey('leaderboard') && data['leaderboard'] is List) {
          try {
            final List<dynamic> rawLeaderboard =
                data['leaderboard'] as List<dynamic>;
            parsedLeaderboard = rawLeaderboard
                .map((item) =>
                    RaceParticipant.fromJson(item as Map<String, dynamic>))
                .toList();
            log("Parsed leaderboard with ${parsedLeaderboard.length} participants.",
                name: 'RaceNotifier');
          } catch (e) {
            log("Error parsing leaderboard data",
                error: e, name: 'RaceNotifier');
            // Hata varsa önceki listeyi kullanmaya devam et
          }
        }

        // 2. Durumu parse et
        final newStatusString = data['status'] as String?;
        RaceStatus parsedStatus = newState.status; // Önceki durumu koru
        if (newStatusString != null) {
          parsedStatus = RaceStatus.values.firstWhere(
            (e) => e.name == newStatusString,
            orElse: () {
              log("Unknown status string '$newStatusString'. Keeping old status: ${newState.status}",
                  name: 'RaceNotifier');
              return newState.status; // Bilinmiyorsa mevcutu koru
            },
          );
        }

        // 3. Hata mesajını kontrol et
        String? errorMessage = newState.errorMessage;
        bool forceErrorNull = true;
        if (parsedStatus == RaceStatus.error) {
          errorMessage = data['error'] as String? ?? "Bilinmeyen servis hatası";
          forceErrorNull = false;
        } else {
          errorMessage = null; // Başarılı durumda hatayı temizle
        }

        // 4. Diğer metrikleri oku
        final int elapsedSeconds =
            data['elapsedSeconds'] as int? ?? newState.elapsedSeconds;
        final int? remainingSeconds =
            data['remainingSeconds'] as int?; // Null olabilir
        final double distanceKm =
            (data['distanceKm'] as num? ?? newState.distanceKm).toDouble();
        final int steps = data['steps'] as int? ?? newState.steps;
        final double speedKmh =
            (data['speedKmh'] as num? ?? newState.speedKmh).toDouble();

        // 5. Başlangıç durumundan geçişi yönet
        // Eğer mevcut durum 'starting' ise ve yeni durum 'error' veya 'stopped' DEĞİLSE
        // durumu 'running' yap (veya zaten running/paused ise onu koru).
        if (state.status == RaceStatus.starting &&
            parsedStatus != RaceStatus.error &&
            parsedStatus != RaceStatus.stopped) {
          final finalStatus = (parsedStatus == RaceStatus.running ||
                  parsedStatus == RaceStatus.paused)
              ? parsedStatus // Eğer zaten running/paused ise onu kullan
              : RaceStatus.running; // Değilse running yap

          if (parsedStatus != finalStatus) {
            log("Transitioning from 'starting' to '$finalStatus' because first valid data received.",
                name: 'RaceNotifier');
            parsedStatus = finalStatus; // Durumu güncelle
          }
        }

        // 6. Yeni state nesnesini oluştur
        newState = state.copyWith(
          status: parsedStatus,
          elapsedSeconds: elapsedSeconds,
          remainingSeconds: remainingSeconds,
          forceRemainingNull: !data.containsKey('remainingSeconds'),
          distanceKm: distanceKm,
          steps: steps,
          speedKmh: speedKmh,
          leaderboard: parsedLeaderboard,
          errorMessage: errorMessage,
          forceErrorNull: forceErrorNull,
        );

        // --- ESKİ KARMAŞIK MANTIK SİLİNDİ ---

        // Sadece gerçekten bir değişiklik varsa state'i güncelle
        if (newState != state) {
          log("Updating state: Status=${newState.status}, LB=${newState.leaderboard.length}, Time=${newState.elapsedSeconds}, Dist=${newState.distanceKm.toStringAsFixed(2)}",
              name: 'RaceNotifier');
          // !!!!!!! DISPOSED KONTROLÜ !!!!!!!
          if (!_isDisposed) {
            state = newState;
          }

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
        // !!!!!!! DISPOSED KONTROLÜ !!!!!!!
        if (!_isDisposed) {
          state = state.copyWith(
            status: RaceStatus.error,
            errorMessage: "Servis bağlantı hatası: $error",
          );
        }
        // Aboneliği sadece hata varsa iptal etmeyelim?
        // _raceUpdateSubscription?.cancel();
        // _raceUpdateSubscription = null; // Referansı temizle
      },
      onDone: () {
        log("Race update stream done.", name: 'RaceNotifier');
        // !!!!!!! DISPOSED KONTROLÜ !!!!!!!
        if (!_isDisposed &&
            (state.status == RaceStatus.running ||
                state.status == RaceStatus.paused)) {
          log("Stream closed unexpectedly. Setting status to idle.",
              name: 'RaceNotifier');
          state = state.copyWith(status: RaceStatus.idle);
        }
        _raceUpdateSubscription = null; // Referansı temizle
      },
      cancelOnError:
          false, // Hata olsa bile stream dinlemeye devam etsin mi? true olabilir.
    );
  }

  // Notifier dispose olduğunda aboneliği iptal et
  @override
  void dispose() {
    log("RaceNotifier disposing. Cancelling subscription if active.",
        name: 'RaceNotifier');
    _isDisposed = true; // Bayrağı true yap
    _raceUpdateSubscription?.cancel();
    super.dispose();
  }
}
