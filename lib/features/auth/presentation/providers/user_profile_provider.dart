import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/models/user_profile_model.dart';
import '../../../../core/config/api_config.dart';
import 'auth_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/http_interceptor.dart';

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
      final String? currentAccessToken = authState.value;

      if (currentAccessToken == null || currentAccessToken.isEmpty) {
        throw Exception('No authentication token found');
      }

      print('Bearer Token for update: $currentAccessToken');
      print('Profile data to send: ${jsonEncode(_profile!.toJson())}');

      final response = await HttpInterceptor.put(
        Uri.parse('${ApiConfig.baseUrl}/User/update-profile'),
        body: jsonEncode(_profile!.toJson()),
      );

      print('Response status for update-profile: ${response.statusCode}');
      print('Response body for update-profile: ${response.body}');

      if (response.statusCode == 200) {
        state = AsyncValue.data(_profile);

        try {
          final Map<String, dynamic> responseDataMap =
              jsonDecode(response.body);
          final String? newApiAccessToken =
              responseDataMap['accessToken'] as String?;

          if (newApiAccessToken != null && newApiAccessToken.isNotEmpty) {
            print(
                '✅ New access token received from update-profile: $newApiAccessToken');
            final String? currentRefreshToken =
                await StorageService.getRefreshToken();

            if (currentRefreshToken != null && currentRefreshToken.isNotEmpty) {
              await StorageService.saveToken(
                accessToken: newApiAccessToken,
                refreshToken: currentRefreshToken,
              );
              _ref.read(authProvider.notifier).state =
                  AsyncValue.data(newApiAccessToken);
              print('✅ New access token saved. AuthProvider state updated.');
            } else {
              print(
                  '⚠️ New access token received, but current refresh token is missing. Tokens not fully updated.');
              _ref.read(authProvider.notifier).state =
                  AsyncValue.data(newApiAccessToken);
            }
          } else {
            print(
                'ℹ️ Profile updated successfully. No new access token found in JSON response.');
          }
        } catch (e) {
          print(
              'ℹ️ Profile updated successfully. Response body was not a JSON or could not be parsed for new tokens: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to update profile: ${response.statusCode} - ${response.body}');
      }
    } catch (error, stack) {
      print('Error in saveProfile: $error');
      state = AsyncValue.error(error, stack);
    }
  }
}
