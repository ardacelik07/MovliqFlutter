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

      final String token = tokenJson;

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

  Future<UserLeaderboardEntryDto?> getLeaderboardByUser(
      String leaderboardType) async {
    try {
      final String? tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        // Return null or throw specific exception if token is required but missing
        debugPrint('Authentication token not found.');
        return null; // Or throw Exception('Authentication token not found');
      }

      final String token = tokenJson;

      final Uri uri = Uri.parse(
          '${ApiConfig.leaderboardByUserEndpoint}?type=$leaderboardType');

      debugPrint("Making request to get user leaderboard: $uri");

      final Map<String, String> headers = {
        ...ApiConfig.headers, // Include standard headers
        'Authorization': 'Bearer $token', // Add auth token
      };

      final http.Response response = await http.get(uri, headers: headers);

      debugPrint("User leaderboard response status: ${response.statusCode}");
      debugPrint("User leaderboard response body: ${response.body}");

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty &&
            (response.body.trim().startsWith('{') ||
                response.body.trim().startsWith('['))) {
          // Check for empty body or non-JSON body which might indicate no rank
          try {
            final Map<String, dynamic> data = jsonDecode(response.body);
            // API returns a single object, not a list
            return UserLeaderboardEntryDto.fromJson(data);
          } catch (e) {
            debugPrint("Error decoding user leaderboard JSON: $e");
            // If decoding fails, it might mean the user isn't ranked or other issue
            return null;
          }
        } else {
          // Handle cases where the response is empty or not JSON (e.g., user not ranked)
          debugPrint(
              'Received empty or non-JSON response for user leaderboard.');
          return null;
        }
      } else if (response.statusCode == 404) {
        // Handle 404 specifically if the API uses it for 'user not found/ranked'
        debugPrint('User leaderboard entry not found (404).');
        return null;
      } else {
        // Handle other error status codes
        debugPrint(
            'Failed to load user leaderboard. Status: ${response.statusCode}');
        // Optionally parse error message if available
        // final errorBody = jsonDecode(response.body);
        // throw Exception(errorBody['message'] ?? 'Failed to load user leaderboard');
        return null; // Return null on error
      }
    } catch (e) {
      debugPrint("Error in getLeaderboardByUser: $e");
      // Re-throw or handle as appropriate for your app's error strategy
      // throw Exception('Failed to load user leaderboard: ${e.toString()}');
      return null; // Return null on exception
    }
  }
}
