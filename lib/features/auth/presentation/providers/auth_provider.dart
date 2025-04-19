import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/signalr_service.dart';

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

      final token = await _repository.register(
        email: email,
        password: password,
      );
      await StorageService.saveToken(token);
      state = AsyncValue.data(token);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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

      final token = await _repository.login(
        email: email,
        password: password,
      );
      await StorageService.saveToken(token);
      state = AsyncValue.data(token);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
