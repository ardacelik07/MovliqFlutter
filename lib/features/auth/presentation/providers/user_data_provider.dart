import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/user_data_model.dart';

class UserDataNotifier extends StateNotifier<AsyncValue<UserDataModel?>> {
  UserDataNotifier() : super(const AsyncValue.data(null));

  // API'den profil verilerini çek
  Future<void> fetchUserData() async {
    try {
      state = const AsyncValue.loading();

      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        state = AsyncValue.error("Token bulunamadı", StackTrace.current);
        return;
      }

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/User/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final userDataModel = UserDataModel.fromJson(userData);
        state = AsyncValue.data(userDataModel);
      } else {
        state = AsyncValue.error(
            "Profil bilgileri alınamadı: ${response.statusCode}",
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // Profil verisini güncelle (örn. profil fotoğrafı değiştiğinde)
  void updateUserData(UserDataModel? updatedData) {
    state = AsyncValue.data(updatedData);
  }

  // Çıkış yaparken provider'ı temizle
  void clearUserData() {
    state = const AsyncValue.data(null);
  }
}

// Provider tanımı
final userDataProvider =
    StateNotifierProvider<UserDataNotifier, AsyncValue<UserDataModel?>>((ref) {
  return UserDataNotifier();
});
