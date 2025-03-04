class RaceRoomRequest {
  final String roomType; // 'outdoors' veya 'gym'
  final int duration; // 10, 20, 30 dakika

  RaceRoomRequest({
    required this.roomType,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'roomType': roomType,
        'duration': duration,
      };
}
