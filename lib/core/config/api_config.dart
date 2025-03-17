class ApiConfig {
  static const String baseUrl =
      'https://23c703a9-aeb4-4a19-bcd9-1bb5a82788de-00-35bgx6xr95c1e.sisko.replit.dev/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';
  static const String matchRoomEndpoint = '$baseUrl/User/match-room';
  static const String addUserRecordEndpoint =
      '$baseUrl/UserResults/add-user-record';
  static const String leaderboardEndpoint =
      '$baseUrl/LeaderBoard/GetAllLeaderboard';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
