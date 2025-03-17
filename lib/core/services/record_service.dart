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

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String actualToken = tokenData['token'];

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
}
