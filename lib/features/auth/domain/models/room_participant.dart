class RoomParticipant {
  final String userName;
  final String? profilePictureUrl;

  RoomParticipant({
    required this.userName,
    this.profilePictureUrl,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      userName: json['userName'] ?? '',
      profilePictureUrl: json['profilePictureUrl'],
    );
  }
}
