import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/services/storage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<String?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.data(null)) {
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
    await StorageService.deleteToken();
    state = const AsyncValue.data(null);
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
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
