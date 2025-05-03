import 'package:freezed_annotation/freezed_annotation.dart';

part 'private_race_model.freezed.dart';
part 'private_race_model.g.dart';

@freezed
class PrivateRaceModel with _$PrivateRaceModel {
  const factory PrivateRaceModel({
    int? id,
    String? roomName, // Internal room identifier?
    String? specialRaceRoomName, // Display name for the race
    String? description,
    String? imagePath, // URL for the race image
    String? type, // e.g., "outdoor"
    int? duration, // Duration in minutes? Check API details
    DateTime? startTime,
    String? giftPoll,
    String? giftPollList, // Start time of the race
    // Add other fields if available from the API in the future
    // For example: participantCount, prizePool, awards etc.
  }) = _PrivateRaceModel;

  factory PrivateRaceModel.fromJson(Map<String, dynamic> json) =>
      _$PrivateRaceModelFromJson(json);
}
