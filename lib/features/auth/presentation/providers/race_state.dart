import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_flutter_project/core/services/signalr_service.dart'; // RaceParticipant için

part 'race_state.freezed.dart';

@freezed
class RaceState with _$RaceState {
  const factory RaceState({
    // Yarışın genel durumu
    @Default(false) bool isRaceActive,
    @Default(false) bool isPreRaceCountdownActive,
    @Default(0) int preRaceCountdownValue,
    @Default(null) int? roomId,
    @Default(null) DateTime? raceStartTime,
    @Default(null) Duration? raceDuration, // Toplam süre
    @Default(Duration.zero) Duration remainingTime, // Kalan süre
    @Default(false) bool isIndoorRace,
    @Default(false) bool isRaceFinished, // <-- Flag to indicate normal finish
    @Default(false)
    bool hasLocationPermission, // UI'da izin durumu göstermek için
    @Default(false)
    bool hasPedometerPermission, // UI'da izin durumu göstermek için

    // Anlık yarış verileri
    @Default(0.0) double currentDistance,
    @Default(0) int currentSteps,
    @Default(0) int initialSteps, // Adım sayacı başlangıç değeri
    @Default(null) String? userEmail, // Mevcut kullanıcının email'i
    @Default([]) List<RaceParticipant> leaderboard,

    // Hile kontrolü
    @Default(0) int violationCount,

    // Hata durumu
    @Default(null) String? errorMessage,
  }) = _RaceState;
}
