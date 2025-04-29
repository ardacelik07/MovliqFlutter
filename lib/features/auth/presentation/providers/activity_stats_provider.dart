import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/activity_stats_model.dart';

// Define parameters for the family
class ActivityStatsParams {
  final String type;
  final String period;

  ActivityStatsParams({required this.type, required this.period});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityStatsParams &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          period == other.period;

  @override
  int get hashCode => type.hashCode ^ period.hashCode;
}

// Standard FutureProvider.family without code generation
final activityStatsProvider =
    FutureProvider.family<ActivityStatsModel, ActivityStatsParams>(
        (ref, params) async {
  final token = await StorageService.getToken();
  if (token == null) {
    throw Exception('Authentication token not found.');
  }

  final Map<String, dynamic> tokenData = jsonDecode(token);
  final String accessToken = tokenData['token'];

  final uri = Uri.parse(
      '${ApiConfig.userActivityStatsEndpoint}?type=${params.type}&period=${params.period}');

  try {
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Use the manual fromJson factory
      return ActivityStatsModel.fromJson(data);
    } else {
      debugPrint(
          'Failed to load activity stats: ${response.statusCode} ${response.body}');
      throw Exception(
          'Failed to load activity stats. Status code: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error fetching activity stats: $e');
    throw Exception('Error fetching activity stats: $e');
  }
});
