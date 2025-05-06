import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:my_flutter_project/core/config/api_config.dart';
import 'package:my_flutter_project/features/auth/domain/models/private_race_model.dart';
import 'package:my_flutter_project/core/services/storage_service.dart'; // For token

part 'private_race_provider.g.dart';

@riverpod
class PrivateRace extends _$PrivateRace {
  @override
  Future<List<PrivateRaceModel>> build() async {
    // Initial fetch
    return _fetchSpecialRaces();
  }

  Future<List<PrivateRaceModel>> _fetchSpecialRaces() async {
    final tokenData = await StorageService.getToken();
    if (tokenData == null) {
      throw Exception('Authentication token not found.');
    }

    final token = tokenData;
    final headers = {
      ...ApiConfig.headers, // Include default headers
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.specialRacesEndpoint),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final races =
            data.map((json) => PrivateRaceModel.fromJson(json)).toList();
        return races;
      } else {
        // Handle specific error codes if needed
        print(
            'Failed to load special races: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Failed to load special races: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error fetching special races: $e');
      // Rethrow to let the UI handle the error state
      throw Exception('Error fetching special races: $e');
    }
  }

  // Optional: Method to manually refresh the data
  Future<void> refreshRaces() async {
    state = const AsyncValue.loading();
    try {
      final races = await _fetchSpecialRaces();
      state = AsyncValue.data(races);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}
