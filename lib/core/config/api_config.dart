class ApiConfig {
  //static const String baseUrl = 'http://movliq.mehmetalicakir.tr:5000/api';
  static const String baseUrl = 'http://10.0.2.2:8080/api';
  //static const String baseUrl = 'http://192.168.1.106:8080/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';
  static const String matchRoomEndpoint = '$baseUrl/User/match-room';
  static const String addUserRecordEndpoint =
      '$baseUrl/UserResults/add-user-record';
  static const String leaderboardEndpoint =
      '$baseUrl/LeaderBoard/GetAllLeaderboard';

  // Son 3 aktiviteyi getirmek için yeni endpoint
  static const String lastThreeActivitiesEndpoint =
      '$baseUrl/UserResults/GetUserLastThreeActivities';

  // Kullanıcının streak sayısını getirmek için endpoint
  static const String userStreakTrackEndpoint =
      '$baseUrl/UserResults/UserStreakTrack';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
