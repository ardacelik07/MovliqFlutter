class LeaderboardIndoorDto {
  final int id;
  final int userId;
  final String userName;
  final String? profilePicture;
  final int? indoorSteps;

  LeaderboardIndoorDto({
    required this.id,
    required this.userId,
    required this.userName,
    this.profilePicture,
    this.indoorSteps,
  });

  factory LeaderboardIndoorDto.fromJson(Map<String, dynamic> json) {
    return LeaderboardIndoorDto(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePicture: json['profilePicture'],
      indoorSteps: json['indoorSteps'],
    );
  }
}

class LeaderboardOutdoorDto {
  final int id;
  final int userId;
  final String userName;
  final int? outdoorSteps;
  final String? profilePicture;
  final double? generalDistance;

  LeaderboardOutdoorDto({
    required this.id,
    required this.userId,
    required this.userName,
    this.profilePicture,
    this.outdoorSteps,
    this.generalDistance,
  });

  factory LeaderboardOutdoorDto.fromJson(Map<String, dynamic> json) {
    return LeaderboardOutdoorDto(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePicture: json['profilePicture'],
      outdoorSteps: json['outdoorSteps'],
      generalDistance: json['generalDistance'] != null
          ? (json['generalDistance'] is int
              ? (json['generalDistance'] as int).toDouble()
              : json['generalDistance'])
          : null,
    );
  }
}
