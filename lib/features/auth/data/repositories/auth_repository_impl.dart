import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/repositories/auth_repository.dart';
import '../../domain/models/auth_model.dart';
import '../../../../core/config/api_config.dart';

class AuthRepositoryImpl implements AuthRepository {
  final http.Client _client;

  AuthRepositoryImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<String> register(
      {required String email, required String password}) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode(AuthModel(
          email: email,
          password: password,
        ).toJson()),
      );

      if (response.statusCode == 200) {
        final token = response.body;

        return token;
      } else {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  @override
  Future<String> login(
      {required String email, required String password}) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode(AuthModel(
          email: email,
          password: password,
        ).toJson()),
      );

      if (response.statusCode == 200) {
        final token = response.body;
        return token;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }
}
