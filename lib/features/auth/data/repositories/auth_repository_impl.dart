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
      print("🔄 AuthRepository: Kullanıcı kaydı yapılıyor...");

      final response = await _client.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode(AuthModel(
          email: email,
          password: password,
        ).toJson()),
      );

      print("📊 AuthRepository: Kayıt API yanıt kodu: ${response.statusCode}");

      if (response.statusCode == 200) {
        final rawToken = response.body;
        print("✅ AuthRepository: Kayıt başarılı, token alındı");

        // Token'ı işle ve JSON formatına dönüştür
        return _processRawToken(rawToken);
      } else {
        print("❌ AuthRepository: Kayıt başarısız: ${response.body}");
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      print("❌ AuthRepository: Kayıt hatası: $e");
      throw Exception('Registration error: $e');
    }
  }

  @override
  Future<String> login(
      {required String email, required String password}) async {
    try {
      print("🔄 AuthRepository: Giriş yapılıyor...");

      final response = await _client.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode(AuthModel(
          email: email,
          password: password,
        ).toJson()),
      );

      print("📊 AuthRepository: Giriş API yanıt kodu: ${response.statusCode}");

      if (response.statusCode == 200) {
        final rawToken = response.body;
        print("✅ AuthRepository: Giriş başarılı, token alındı");

        // Token'ı işle ve JSON formatına dönüştür
        return _processRawToken(rawToken);
      } else {
        print("❌ AuthRepository: Giriş başarısız: ${response.body}");
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      print("❌ AuthRepository: Giriş hatası: $e");
      throw Exception('Login error: $e');
    }
  }

  // Token'ı işle ve standart JSON formatına çevir
  String _processRawToken(String rawToken) {
    try {
      // Ham token uzunluğu
      print(
          "📝 AuthRepository: Ham token işleniyor, uzunluk: ${rawToken.length}");

      // Önce JSON olarak ayrıştırmayı dene
      try {
        final jsonToken = jsonDecode(rawToken);

        // Token doğru JSON formatında mı kontrol et
        if (jsonToken is Map<String, dynamic> &&
            jsonToken.containsKey('token')) {
          print("✅ AuthRepository: Token zaten doğru JSON formatında");
          return jsonEncode(jsonToken);
        } else {
          // JSON ama 'token' alanı yok, düzelt
          print(
              "🔄 AuthRepository: JSON formatında ama 'token' alanı yok, düzeltiliyor");
          return jsonEncode({'token': rawToken});
        }
      } catch (e) {
        // JSON olarak ayrıştırılamadı, düz string olmalı
        print("🔄 AuthRepository: Token JSON formatında değil, düzeltiliyor");
        return jsonEncode({'token': rawToken});
      }
    } catch (e) {
      print("⚠️ AuthRepository: Token işleme hatası: $e");
      // Hata durumunda bile bir şey döndür
      return jsonEncode({'token': rawToken});
    }
  }
}
