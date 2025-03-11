class ApiConfig {
  static const String baseUrl =
      'https://9fa01592-3c70-4909-a300-563d3a7c8103-00-3761b1o31qp21.sisko.replit.dev/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';
  static const String matchRoomEndpoint = '$baseUrl/User/match-room';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
