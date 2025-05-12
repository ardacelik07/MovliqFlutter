import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';
import '../../features/auth/domain/models/record_request_model.dart';

class RecordService {
  Future<Map<String, dynamic>> addUserRecord(RecordRequestModel request) async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        throw Exception('Authentication token not found');
      }

      final String actualToken = tokenJson;

      final response = await http.post(
        Uri.parse(ApiConfig.addUserRecordEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $actualToken',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to add user record');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Yeni method: Aktivite mesafesine göre coin kazanma isteği
  Future<double> recordEarnCoin(double distance) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Mesafeyi query parametresi olarak ekleyerek URL oluştur
      final uri = Uri.parse(
          '${ApiConfig.userRecordEarnCoinEndpoint}?distance=${distance.toString()}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          // POST isteği için Content-Type gerekli olmayabilir,
          // backend'in nasıl yapılandırıldığına bağlıdır.
          // Sorun olursa 'Content-Type': 'application/json' eklenebilir.
        },
        // Body boş gönderilebilir veya backend beklentisine göre düzenlenebilir
      );

      if (response.statusCode == 200) {
        // Backend doğrudan double döndürdüğü için direkt decode et
        final dynamic decodedBody = jsonDecode(response.body);
        if (decodedBody is num) {
          return decodedBody.toDouble();
        } else {
          // Beklenmedik format
          throw Exception('API did not return a valid number for earned coin.');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            errorBody['message'] ?? 'Failed to earn coin for record');
      }
    } catch (e) {
      // Ağ hatası veya diğer istisnalar
      throw Exception('Network error during coin earning: ${e.toString()}');
    }
  }
}
