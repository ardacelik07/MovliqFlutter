// lib/features/auth/presentation/providers/race_coin_tracker_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RaceCoinTrackingState {
  final double? beforeRaceCoin;
  final bool justFinishedRace;

  RaceCoinTrackingState({
    this.beforeRaceCoin,
    this.justFinishedRace = false,
  });

  RaceCoinTrackingState copyWith({
    double? beforeRaceCoin,
    bool? justFinishedRace,
  }) {
    return RaceCoinTrackingState(
      // Eğer yeni değer null ise eskisini koru (?? operatörü ile)
      // Ama null olmasına izin vermek için explicit null check daha iyi olabilir
      beforeRaceCoin: beforeRaceCoin ?? this.beforeRaceCoin,
      justFinishedRace: justFinishedRace ?? this.justFinishedRace,
    );
  }
}

final raceCoinTrackingProvider =
    StateNotifierProvider<RaceCoinTrackingNotifier, RaceCoinTrackingState?>(
        (ref) {
  return RaceCoinTrackingNotifier();
});

class RaceCoinTrackingNotifier extends StateNotifier<RaceCoinTrackingState?> {
  RaceCoinTrackingNotifier() : super(null); // Başlangıçta null

  void setBeforeRaceCoin(double coins) {
    print("🏁 RaceCoinTracker: Yarış öncesi coin kaydedildi: $coins");
    state =
        RaceCoinTrackingState(beforeRaceCoin: coins, justFinishedRace: false);
  }

  void markRaceAsFinished() {
    if (state != null) {
      print("🏁 RaceCoinTracker: Yarış bitti olarak işaretleniyor.");
      state = state!.copyWith(justFinishedRace: true);
    } else {
      print("🏁 RaceCoinTracker: Yarış bitti işaretlenemedi, state null.");
      // Belki de yarış öncesi coin hiç set edilmediyse, boş bir state oluştur.
      // state = RaceCoinTrackingState(justFinishedRace: true);
    }
  }

  void clearState() {
    print("🏁 RaceCoinTracker: State temizleniyor.");
    state = null;
  }
}
