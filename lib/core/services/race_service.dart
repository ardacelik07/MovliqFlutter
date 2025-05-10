import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../features/auth/domain/models/race_room_request.dart';
import '../config/api_config.dart';
import 'storage_service.dart';
import 'http_interceptor.dart';

class RaceService {
  Future<Map<String, dynamic>> joinRaceRoom(RaceRoomRequest request) async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        throw Exception('Authentication token not found');
      }
      final String actualToken = tokenJson;

      // HttpInterceptor kullanarak istek yap (401 durumunda otomatik logout olacak)
      final response = await HttpInterceptor.post(
        Uri.parse('${ApiConfig.baseUrl}/RaceRoom/match-room'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $actualToken',
        },
        body: jsonEncode(request.toJson()),
      );
      print('Actual Token: $actualToken');
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to join race room');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
