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
        print("❌ UserDataProvider: Token bulunamadı");
        return;
      }

      print("📝 UserDataProvider: İşlenen ham token: $tokenJson");

      String token;
      try {
        final Map<String, dynamic> tokenData = jsonDecode(tokenJson);

        if (!tokenData.containsKey('token')) {
          print(
              "⚠️ UserDataProvider: Token JSON formatında ancak 'token' alanı yok");
          print("⚠️ Token verileri: $tokenData");
          state =
              AsyncValue.error("Token formatı geçersiz", StackTrace.current);
          return;
        }

        token = tokenData['token'];
        print("✅ UserDataProvider: Token başarıyla ayrıştırıldı: $token");
      } catch (e) {
        print(
            "⚠️ UserDataProvider: Token JSON formatında değil, ham string olarak kullanılacak");
        token = tokenJson;
      }

      print("🔄 UserDataProvider: Profil verisi isteniyor...");
      final response = await http.get(
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
      } else if (response.statusCode == 401) {
        print("⚠️ UserDataProvider: Oturum geçersiz veya süresi dolmuş");
        state = AsyncValue.error(
            "Oturum süresi dolmuş, lütfen tekrar giriş yapın",
            StackTrace.current);

        // Oturum geçersiz ise tokeni sil
        await StorageService.deleteToken();
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
      print("❌ UserStreakProvider: Token bulunamadı");
      throw Exception('Token bulunamadı');
    }

    String token;
    try {
      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      if (!tokenData.containsKey('token')) {
        print("⚠️ UserStreakProvider: Token formatı geçersiz");
        throw Exception('Token formatı geçersiz');
      }
      token = tokenData['token'];
    } catch (e) {
      print(
          "⚠️ UserStreakProvider: Token JSON formatında değil, ham string olarak kullanılacak");
      token = tokenJson;
    }

    final response = await http.get(
      Uri.parse(ApiConfig.userStreakTrackEndpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final streakCount = int.tryParse(response.body) ?? 0;
      return streakCount;
    } else if (response.statusCode == 401) {
      print("⚠️ UserStreakProvider: Oturum geçersiz veya süresi dolmuş");
      // Oturum geçersiz ise tokeni sil
      await StorageService.deleteToken();
      return 0;
    } else {
      print(
          "❌ UserStreakProvider: Streak verisi alınamadı - HTTP ${response.statusCode}");
      return 1;
    }
  } catch (e) {
    print("❌ UserStreakProvider: Hata: $e");
    return 2;
  }
});
