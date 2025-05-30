import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/signalr_service.dart';
import 'dart:convert';
import 'dart:math';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<String?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final signalRService = ref.watch(signalRServiceProvider);
  return AuthNotifier(repository, signalRService);
});

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  final AuthRepository _repository;
  final SignalRService _signalRService;

  AuthNotifier(this._repository, this._signalRService)
      : super(const AsyncValue.data(null)) {
    _initializeToken();
  }

  Future<void> _initializeToken() async {
    final savedToken = await StorageService.getToken();
    if (savedToken != null) {
      state = AsyncValue.data(savedToken);
    }
  }

  Future<void> register(
      {required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await _signalRService.resetConnection();

      final String responseBody = await _repository.register(
        email: email,
        password: password,
      );

      final Map<String, dynamic> responseData = jsonDecode(responseBody);

      final String? actualAccessToken = responseData['accessToken'] as String?;
      final String? actualRefreshToken =
          responseData['refreshToken'] as String?;

      if (actualAccessToken != null &&
          actualAccessToken.isNotEmpty &&
          actualRefreshToken != null &&
          actualRefreshToken.isNotEmpty) {
        await StorageService.saveToken(
          accessToken: actualAccessToken,
          refreshToken: actualRefreshToken,
        );
        state = AsyncValue.data(actualAccessToken);
        print('Registration successful and tokens parsed and saved correctly.');
      } else {
        print('Error: Tokens not found in registration response or are empty.');
        throw Exception(
            'Invalid token data received from server after registration.');
      }
    } catch (e, stack) {
      print('Registration Provider Error: $e');
      Object errorForState;
      String exceptionString = e.toString();

      int jsonStartIndex = exceptionString.indexOf('{');
      int jsonEndIndex = exceptionString.lastIndexOf('}');

      if (jsonStartIndex != -1 && jsonEndIndex > jsonStartIndex) {
        String potentialJson =
            exceptionString.substring(jsonStartIndex, jsonEndIndex + 1);
        try {
          var decoded = jsonDecode(potentialJson);
          if (decoded is Map<String, dynamic> &&
              decoded.containsKey('message')) {
            errorForState = decoded;
          } else if (decoded is Map<String, dynamic>) {
            String fallbackMessage =
                'Sunucudan detay alınamadı: ${decoded.toString().substring(0, min(decoded.toString().length, 100))}';
            errorForState = {'message': fallbackMessage};
          } else {
            errorForState = {'message': potentialJson};
          }
        } catch (jsonError) {
          errorForState = {'message': exceptionString};
        }
      } else {
        errorForState = {'message': exceptionString};
      }
      state = AsyncValue.error(errorForState, stack);
    }
  }

  Future<void> logout() async {
    await _signalRService.resetConnection();
    await StorageService.deleteToken();
    state = const AsyncValue.data(null);
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await _signalRService.resetConnection();

      final String responseBody = await _repository.login(
        email: email,
        password: password,
      );

      final Map<String, dynamic> responseData = jsonDecode(responseBody);

      final String? actualAccessToken = responseData['accessToken'] as String?;
      final String? actualRefreshToken =
          responseData['refreshToken'] as String?;

      if (actualAccessToken != null &&
          actualAccessToken.isNotEmpty &&
          actualRefreshToken != null &&
          actualRefreshToken.isNotEmpty) {
        await StorageService.saveToken(
          accessToken: actualAccessToken,
          refreshToken: actualRefreshToken,
        );
        state = AsyncValue.data(actualAccessToken);
        print('Login successful and tokens parsed and saved correctly.');
      } else {
        print('Error: Tokens not found in parsed response or are empty.');
        throw Exception('Invalid token data received from server.');
      }
    } catch (e, stack) {
      print('Login Provider Error: $e');

      Object errorForState;
      String exceptionString = e.toString();

      int jsonStartIndex = exceptionString.indexOf('{');
      int jsonEndIndex = exceptionString.lastIndexOf('}');

      if (jsonStartIndex != -1 && jsonEndIndex > jsonStartIndex) {
        String potentialJson =
            exceptionString.substring(jsonStartIndex, jsonEndIndex + 1);
        try {
          var decoded = jsonDecode(potentialJson);
          if (decoded is Map<String, dynamic> &&
              decoded.containsKey('message')) {
            errorForState = decoded;
          } else if (decoded is Map<String, dynamic>) {
            String fallbackMessage =
                'Sunucudan detay alınamadı: ${decoded.toString().substring(0, min(decoded.toString().length, 100))}';
            errorForState = {'message': fallbackMessage};
          } else {
            errorForState = {'message': potentialJson};
          }
        } catch (jsonError) {
          errorForState = {'message': exceptionString};
        }
      } else {
        errorForState = {'message': exceptionString};
      }
      state = AsyncValue.error(errorForState, stack);
    }
  }
}
