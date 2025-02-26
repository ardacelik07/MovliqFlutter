import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/models/user_profile_model.dart';
import '../../../../core/config/api_config.dart';
import 'auth_provider.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfileModel?>>(
        (ref) => UserProfileNotifier(ref));

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfileModel?>> {
  final Ref _ref;

  UserProfileNotifier(this._ref) : super(const AsyncValue.data(null));

  UserProfileModel? _profile;

  void updateProfile({
    String? name,
    String? username,
    DateTime? birthDate,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    String? runningPreference,
  }) {
    _profile = UserProfileModel(
      name: name ?? _profile?.name ?? '',
      username: username ?? _profile?.username ?? '',
      birthDate: birthDate ?? _profile?.birthDate ?? DateTime.now(),
      gender: gender ?? _profile?.gender ?? '',
      height: height ?? _profile?.height ?? 0.0,
      weight: weight ?? _profile?.weight ?? 0.0,
      activityLevel: activityLevel ?? _profile?.activityLevel ?? '',
      runningPreference: runningPreference ?? _profile?.runningPreference ?? '',
    );
    state = AsyncValue.data(_profile);
  }

  Future<void> saveProfile() async {
    if (_profile == null) return;

    state = const AsyncValue.loading();
    try {
      final authState = _ref.read(authProvider);
      final tokenJson = authState.value;

      if (tokenJson == null) throw Exception('No authentication token found');

      // JSON string'i parse edip token değerini alalım
      final tokenData = jsonDecode(tokenJson);
      final token = tokenData['token'] as String;

      print('Bearer Token: $token'); // Debug için
      print('Profile data: ${jsonEncode(_profile!.toJson())}'); // Debug için

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/User/update-profile'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(_profile!.toJson()),
      );

      print('Response status: ${response.statusCode}'); // Debug için
      print('Response body: ${response.body}'); // Debug için

      if (response.statusCode == 200) {
        state = AsyncValue.data(_profile);
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (error, stack) {
      print('Error: $error'); // Debug için
      state = AsyncValue.error(error, stack);
    }
  }
}
