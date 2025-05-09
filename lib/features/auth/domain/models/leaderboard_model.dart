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

// Model for the response from /api/LeaderBoard/GetAllLeaderboardByUser
class UserLeaderboardEntryDto {
  final int id;
  final int userId;
  final String userName;
  final String? profilePicture;
  final int? outdoorSteps;
  final int? indoorSteps;
  final double? generalDistance;
  final int rank;

  UserLeaderboardEntryDto({
    required this.id,
    required this.userId,
    required this.userName,
    this.profilePicture,
    this.outdoorSteps,
    this.indoorSteps,
    this.generalDistance,
    required this.rank,
  });

  factory UserLeaderboardEntryDto.fromJson(Map<String, dynamic> json) {
    return UserLeaderboardEntryDto(
      id: json['id'] as int,
      userId: json['userId'] as int,
      userName: json['userName'] as String,
      profilePicture: json['profilePicture'] as String?,
      outdoorSteps: json['outdoorSteps'] as int?,
      indoorSteps: json['indoorSteps'] as int?,
      generalDistance: (json['generalDistance'] as num?)?.toDouble(),
      rank: json['rank'] as int,
    );
  }
}
