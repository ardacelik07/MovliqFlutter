import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';

// ActivityModel sınıfını doğrudan burada tanımlıyorum
class ActivityModel {
  final int id;
  final int userId;
  final String userName;
  final String email;
  final double distancekm;
  final int steps;
  final DateTime startTime;
  final String roomType;
  final int duration;
  final int? calories;
  final int? avarageSpeed;
  final int? rank;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.distancekm,
    required this.steps,
    required this.startTime,
    required this.roomType,
    required this.duration,
    this.calories,
    this.avarageSpeed,
    this.rank,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'] ?? '',
      email: json['email'] ?? '',
      distancekm: (json['distancekm'] ?? 0.0).toDouble(),
      steps: json['steps'] ?? 0,
      startTime: DateTime.parse(json['startTime']),
      roomType: json['roomType'] ?? '',
      duration: json['duration'] ?? 0,
      calories: json['calories'],
      avarageSpeed: json['avarageSpeed'],
      rank: json['rank'],
    );
  }
}

// Activity sonuçlarını döndürecek provider - Önceki isim: activityDataProvider
final activityProfileProvider = StateNotifierProvider<UserActivityNotifier,
    AsyncValue<List<ActivityModel>>>(
  (ref) => UserActivityNotifier(),
);

// Önceki isim: ActivityNotifier
class UserActivityNotifier
    extends StateNotifier<AsyncValue<List<ActivityModel>>> {
  UserActivityNotifier() : super(const AsyncValue.loading());

  Future<void> fetchActivities(String type, String period) async {
    try {
      state = const AsyncValue.loading();

      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        throw Exception('Oturum açmanız gerekiyor');
      }

      final String token = tokenJson;

      final url = Uri.parse(
          '${ApiConfig.baseUrl}/UserResults/GetUserActivities?type=$type&period=$period');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        final activities =
            responseData.map((data) => ActivityModel.fromJson(data)).toList();

        // Tarihe göre sırala
        activities.sort((a, b) => a.startTime.compareTo(b.startTime));

        state = AsyncValue.data(activities);
      } else {
        throw Exception('Veriler alınamadı. Hata kodu: ${response.statusCode}');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
