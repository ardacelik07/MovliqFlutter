class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:5041/api';

  static const String registerEndpoint = '$baseUrl/User/register';
  static const String loginEndpoint = '$baseUrl/User/login';
  static const String updateProfileEndpoint = '$baseUrl/User/update-profile';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
