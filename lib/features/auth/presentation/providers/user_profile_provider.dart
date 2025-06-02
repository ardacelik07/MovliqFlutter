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

  Future<void> validateAndSetUsername(String newUsername) async {
    // This method focuses on the API call for username validation and update.
    // NameScreen will manage its own overall loading state for the button.
    // We can set loading for the provider state if specific parts of UI listen to it.
    final previousState =
        state; // Keep previous state in case of failure to revert if needed.
    state = const AsyncValue.loading();

    try {
      final response = await HttpInterceptor.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/User/update-username'), // Your new endpoint
        body: jsonEncode({'NewUsername': newUsername}),
      );

      if (response.statusCode == 200) {
        // API call was successful, username is validated and updated on the server.
        // Update the username in the local _profile model.
        _profile = UserProfileModel(
          name: _profile?.name ?? '', // Keep existing name if any
          username: newUsername, // Set the new username
          birthDate: _profile?.birthDate ?? DateTime.now(),
          gender: _profile?.gender ?? '',
          height: _profile?.height ?? 0.0,
          weight: _profile?.weight ?? 0.0,
          activityLevel: _profile?.activityLevel ?? '',
          runningPreference: _profile?.runningPreference ?? '',
        );
        state = AsyncValue.data(_profile); // Update the notifier's state
      } else {
        // API error (e.g., 409 Conflict for username, or other server errors)
        String errorMessage = 'Kullanıcı adı güncellenemedi.';
        try {
          final responseBody = jsonDecode(response.body);
          if (responseBody is Map && responseBody.containsKey('message')) {
            errorMessage = responseBody['message'];
          } else if (responseBody is String && responseBody.isNotEmpty) {
            errorMessage = responseBody;
          } else {
            errorMessage =
                'Hata ${response.statusCode}: ${response.reasonPhrase ?? 'Sunucu hatası'}';
          }
        } catch (_) {
          // If parsing fails, use the raw response body or a default message
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }
        state =
            previousState; // Revert to previous state on specific API failure
        throw Exception(errorMessage);
      }
    } catch (e) {
      state = AsyncValue.error(
          e, StackTrace.current); // Set error state for the provider
      rethrow; // Rethrow to be caught by NameScreen's UI logic
    }
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

      final response = await HttpInterceptor.put(
        Uri.parse('${ApiConfig.baseUrl}/User/update-profile'),
        body: jsonEncode(_profile!.toJson()),
      );

      if (response.statusCode == 200) {
        state = AsyncValue.data(_profile);

        try {
          final Map<String, dynamic> responseDataMap =
              jsonDecode(response.body);
          final String? newApiAccessToken =
              responseDataMap['accessToken'] as String?;

          if (newApiAccessToken != null && newApiAccessToken.isNotEmpty) {
            final String? currentRefreshToken =
                await StorageService.getRefreshToken();

            if (currentRefreshToken != null && currentRefreshToken.isNotEmpty) {
              await StorageService.saveToken(
                accessToken: newApiAccessToken,
                refreshToken: currentRefreshToken,
              );
              _ref.read(authProvider.notifier).state =
                  AsyncValue.data(newApiAccessToken);
            } else {
              _ref.read(authProvider.notifier).state =
                  AsyncValue.data(newApiAccessToken);
            }
          } else {}
        } catch (e) {}
      } else {
        throw Exception(
            'Failed to update profile: ${response.statusCode} - ${response.body}');
      }
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}
