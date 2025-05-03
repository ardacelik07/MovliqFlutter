class ApiConfig {
  static const String baseUrl = 'http://movliq.mehmetalicakir.tr:5000/api';
  //static const String baseUrl = 'http://10.0.2.2:8080/api';
  //static const String baseUrl = 'http://192.168.1.106:8080/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';
  static const String matchRoomEndpoint = '$baseUrl/User/match-room';
  static const String addUserRecordEndpoint =
      '$baseUrl/UserResults/add-user-record';
  static const String leaderboardEndpoint =
      '$baseUrl/LeaderBoard/GetAllLeaderboard';

  // Endpoint to get leaderboard by user type
  static const String leaderboardByUserEndpoint =
      '$baseUrl/LeaderBoard/GetAllLeaderboardByUser';

  // Son 3 aktiviteyi getirmek için yeni endpoint
  static const String lastThreeActivitiesEndpoint =
      '$baseUrl/UserResults/GetUserLastThreeActivities';

  // Kullanıcının streak sayısını getirmek için endpoint
  static const String userStreakTrackEndpoint =
      '$baseUrl/UserResults/UserStreakTrack';

  // Ürünleri getirmek için yeni endpoint
  static const String productsEndpoint = '$baseUrl/Products';

  // Şifre Sıfırlama Endpointleri
  static const String requestPasswordResetEndpoint =
      '$baseUrl/User/request-password-reset';
  static const String verifyResetCodeEndpoint =
      '$baseUrl/User/verify-reset-code';
  static const String resetPasswordVerifiedEndpoint =
      '$baseUrl/User/reset-password-verified';

  // Endpoint to get user activity statistics based on type and period
  static const String userActivityStatsEndpoint =
      '$baseUrl/UserResults/GetUserActivityStats';

  // Endpoint for special races
  static const String specialRacesEndpoint = '$baseUrl/RaceRoom/special/all';

  // Endpoint for matching/joining a private/special race room
  static const String matchPrivateRoomEndpoint =
      '$baseUrl/RaceRoom/match-room-private';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
