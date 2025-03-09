class ApiConfig {
  static const String baseUrl =
      'https://4076dd9b-ccf2-4e43-89ba-13fb8b19e757-00-sokk3788skfw.kirk.replit.dev/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';
  static const String matchRoomEndpoint = '$baseUrl/User/match-room';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
