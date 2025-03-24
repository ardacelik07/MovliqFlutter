import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../features/auth/domain/models/race_room_request.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class RaceService {
  Future<Map<String, dynamic>> joinRaceRoom(RaceRoomRequest request) async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        print("❌ RaceService: Token bulunamadı");
        throw Exception('Authentication token not found');
      }

      String actualToken;
      try {
        final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
        if (!tokenData.containsKey('token')) {
          print(
              "⚠️ RaceService: Token JSON formatında ancak 'token' alanı yok");
          throw Exception('Invalid token format');
        }
        actualToken = tokenData['token'];
        print("✅ RaceService: Token başarıyla ayrıştırıldı");
      } catch (e) {
        print(
            "⚠️ RaceService: Token JSON formatında değil, ham string olarak kullanılacak");
        actualToken = tokenJson;
      }

      print("🔄 RaceService: Yarış odası oluşturma isteği gönderiliyor...");
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/RaceRoom/match-room'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $actualToken',
        },
        body: jsonEncode(request.toJson()),
      );
      print('📝 RaceService: Kullanılan Token: $actualToken');
      print('📊 RaceService: API Yanıt Kodu: ${response.statusCode}');
      print('📋 RaceService: API Yanıt İçeriği: ${response.body}');

      if (response.statusCode == 200) {
        print("✅ RaceService: Yarış odası başarıyla oluşturuldu");
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        print("⚠️ RaceService: Oturum geçersiz veya süresi dolmuş");
        await StorageService.deleteToken(); // Geçersiz token'ı sil
        throw Exception('Session expired, please login again');
      } else {
        final errorBody = jsonDecode(response.body);
        print(
            "❌ RaceService: Hata: ${errorBody['message'] ?? 'Bilinmeyen hata'}");
        throw Exception(errorBody['message'] ?? 'Failed to join race room');
      }
    } catch (e) {
      print("❌ RaceService: İstek hatası: $e");
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
