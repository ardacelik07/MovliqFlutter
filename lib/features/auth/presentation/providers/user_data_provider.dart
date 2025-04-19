import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/http_interceptor.dart';
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
        print("❌ UserDataProvider: Token bulunamadı");
        return;
      }

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      // HttpInterceptor kullanarak istek yap (401 durumunda otomatik logout olacak)
      final response = await HttpInterceptor.get(
        Uri.parse('${ApiConfig.baseUrl}/User/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print("📊 UserDataProvider: API yanıtı - Status ${response.statusCode}");

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        print(
            "✅ UserDataProvider: Veri başarıyla alındı ${userData['userName']}");

        final userDataModel = UserDataModel.fromJson(userData);
        state = AsyncValue.data(userDataModel);
        print("✅ UserDataProvider: State güncellendi, yeni veri ile");
      } else {
        print(
            "❌ UserDataProvider: Profil verileri alınamadı - HTTP ${response.statusCode}");
        print("❌ Yanıt: ${response.body}");
        state = AsyncValue.error(
            "Profil bilgileri alınamadı: ${response.statusCode}",
            StackTrace.current);
      }
    } catch (e, stackTrace) {
      print("❌ UserDataProvider: Hata: $e");
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

// Kullanıcı streak sayısını getiren provider
final userStreakProvider = FutureProvider<int>((ref) async {
  try {
    final tokenJson = await StorageService.getToken();
    if (tokenJson == null) {
      throw Exception('Token bulunamadı');
    }

    final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
    final String token = tokenData['token'];

    // HttpInterceptor kullanarak istek yap (401 durumunda otomatik logout olacak)
    final response = await HttpInterceptor.get(
      Uri.parse(ApiConfig.userStreakTrackEndpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final streakCount = int.tryParse(response.body) ?? 0;
      return streakCount;
    } else {
      print(
          "❌ UserStreakProvider: Streak verisi alınamadı - HTTP ${response.statusCode}");
      return 0;
    }
  } catch (e) {
    print("❌ UserStreakProvider: Hata: $e");
    return 0;
  }
});
