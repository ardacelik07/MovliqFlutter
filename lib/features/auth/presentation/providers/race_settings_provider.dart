import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/race_room_request.dart';
import '../../../../core/services/race_service.dart';

// Race settings state
class RaceSettings {
  final String? roomType;
  final int? duration;

  RaceSettings({this.roomType, this.duration});

  RaceSettings copyWith({
    String? roomType,
    int? duration,
  }) {
    return RaceSettings(
      roomType: roomType ?? this.roomType,
      duration: duration ?? this.duration,
    );
  }

  bool get isComplete => roomType != null && duration != null;

  RaceRoomRequest toRequest() {
    if (!isComplete) {
      throw Exception('Race settings are incomplete');
    }
    return RaceRoomRequest(
      roomType: roomType!,
      duration: duration!,
    );
  }
}

class RaceSettingsNotifier extends StateNotifier<RaceSettings> {
  RaceSettingsNotifier() : super(RaceSettings());

  void setRoomType(String roomType) {
    state = state.copyWith(roomType: roomType);
  }

  void setDuration(int duration) {
    state = state.copyWith(duration: duration);
  }

  void reset() {
    state = RaceSettings();
  }
}

final raceSettingsProvider =
    StateNotifierProvider<RaceSettingsNotifier, RaceSettings>((ref) {
  return RaceSettingsNotifier();
});

// Race join provider
final raceJoinProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, RaceRoomRequest>((ref, request) async {
  final raceService = RaceService();
  return await raceService.joinRaceRoom(request);
});
