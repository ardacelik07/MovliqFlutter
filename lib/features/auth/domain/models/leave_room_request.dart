class LeaveRoomRequest {
  final int raceRoomId;

  LeaveRoomRequest({required this.raceRoomId});

  Map<String, dynamic> toJson() => {
        'raceRoomId': raceRoomId,
      };
}
