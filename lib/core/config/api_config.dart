class ApiConfig {
  static const String baseUrl = 'http://movliq.mehmetalicakir.tr:5000/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';
  static const String matchRoomEndpoint = '$baseUrl/User/match-room';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
