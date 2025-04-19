import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../../features/auth/domain/models/leaderboard_model.dart';
import '../services/storage_service.dart';

class LeaderboardService {
  Future<List<LeaderboardIndoorDto>> getIndoorLeaderboard() async {
    try {
      // Print debug information
      debugPrint(
          "Making request to: ${ApiConfig.leaderboardEndpoint}?type=indoor");

      final response = await http.get(
        Uri.parse('${ApiConfig.leaderboardEndpoint}?type=indoor'),
        headers:
            ApiConfig.headers, // Sadece standart header'ları kullan, token yok
      );

      // Print response for debugging
      debugPrint("Response status: ${response.statusCode}");
      debugPrint(
          "Response body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...");

      if (response.statusCode == 200) {
        // Check if response is actually JSON
        if (response.body.trim().startsWith('{') ||
            response.body.trim().startsWith('[')) {
          final List<dynamic> data = jsonDecode(response.body);
          return data
              .map((json) => LeaderboardIndoorDto.fromJson(json))
              .toList();
        } else {
          throw Exception(
              'Invalid response format: API returned non-JSON data: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(
              errorBody['message'] ?? 'Failed to load indoor leaderboard');
        } catch (e) {
          throw Exception(
              'Failed to load indoor leaderboard. Status: ${response.statusCode}, Body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      debugPrint("Error in getIndoorLeaderboard: $e");
      throw Exception('Failed to load indoor leaderboard: ${e.toString()}');
    }
  }

  Future<List<LeaderboardOutdoorDto>> getOutdoorLeaderboard() async {
    try {
      // Print debug information
      debugPrint(
          "Making request to: ${ApiConfig.leaderboardEndpoint}?type=outdoor");

      final response = await http.get(
        Uri.parse('${ApiConfig.leaderboardEndpoint}?type=outdoor'),
        headers:
            ApiConfig.headers, // Sadece standart header'ları kullan, token yok
      );

      // Print response for debugging
      debugPrint("Response status: ${response.statusCode}");
      debugPrint(
          "Response body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...");

      if (response.statusCode == 200) {
        // Check if response is actually JSON
        if (response.body.trim().startsWith('{') ||
            response.body.trim().startsWith('[')) {
          final List<dynamic> data = jsonDecode(response.body);
          return data
              .map((json) => LeaderboardOutdoorDto.fromJson(json))
              .toList();
        } else {
          throw Exception(
              'Invalid response format: API returned non-JSON data: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(
              errorBody['message'] ?? 'Failed to load outdoor leaderboard');
        } catch (e) {
          throw Exception(
              'Failed to load outdoor leaderboard. Status: ${response.statusCode}, Body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      debugPrint("Error in getOutdoorLeaderboard: $e");
      throw Exception('Failed to load outdoor leaderboard: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getUserLeaderboardRanks() async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        throw Exception('Kimlik doğrulama jetonu bulunamadı');
      }

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/LeaderBoard/GetUserByIdLeaderBoardRanks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint("Sıralama API yanıt durumu: ${response.statusCode}");
      debugPrint("Sıralama API yanıt gövdesi: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Kullanıcı sıralaması alınamadı. Durum: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("getUserLeaderboardRanks metodunda hata: $e");
      throw Exception('Kullanıcı sıralaması alınamadı: ${e.toString()}');
    }
  }
}
