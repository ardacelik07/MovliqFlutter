import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/http_interceptor.dart';
import '../../domain/models/user_data_model.dart';

// Provider'ı keepAlive olarak işaretleyelim, böylece state korunur
final userDataProvider =
    StateNotifierProvider<UserDataNotifier, AsyncValue<UserDataModel?>>((ref) {
  return UserDataNotifier();
});

class UserDataNotifier extends StateNotifier<AsyncValue<UserDataModel?>> {
  UserDataNotifier() : super(const AsyncValue.data(null)) {
    // Provider oluşturulduğunda kullanıcı verisini çek
    fetchUserData();
  }

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

  // API'den sadece coin bilgisini çek
  Future<void> fetchCoins() async {
    final currentState = state.value;
    if (currentState == null) {
      print("❌ UserDataProvider: Önce profil verisi çekilmeli.");
      // Henüz profil verisi yoksa, önce onu çekmeyi deneyebiliriz.
      await fetchUserData();
      // Eğer hala veri yoksa veya hata varsa çık
      if (state.value == null || state.hasError) return;
    }

    try {
      print("💰 Fetching coins...");
      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        print("❌ UserDataProvider: Token bulunamadı (fetchCoins)");
        return; // Hata state'i ayarlamaya gerek yok, mevcut state kalsın
      }

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      final response = await HttpInterceptor.get(
        Uri.parse('${ApiConfig.baseUrl}/User/my-coins'), // Yeni endpoint
        headers: {
          'Authorization': 'Bearer $token',
          'Accept':
              'application/json', // Genellikle coin gibi basit veriler için de JSON beklenir
        },
      );

      print(
          "💰 UserDataProvider: Coins API yanıtı - Status ${response.statusCode}");

      if (response.statusCode == 200) {
        // API'nin sadece sayıyı mı yoksa { "coins": sayı } şeklinde mi döndüğünü kontrol et
        final dynamic responseData = jsonDecode(response.body);
        int coins = 0;
        if (responseData is int) {
          coins = responseData;
        } else if (responseData is Map<String, dynamic> &&
            responseData.containsKey('coins')) {
          coins = responseData['coins'] ?? 0;
        } else {
          // Beklenmedik format, logla ve 0 ata
          print(
              "❌ UserDataProvider: Beklenmedik coin yanıt formatı: ${response.body}");
        }

        print("✅ UserDataProvider: Coins başarıyla alındı: $coins");

        // Mevcut state'i güncelle, sadece coins değerini değiştir
        if (state.value != null) {
          final updatedModel =
              state.value!.copyWith(coins: coins); // copyWith eklenmeli
          state = AsyncValue.data(updatedModel);
          print("✅ UserDataProvider: State (coins) güncellendi.");
        }
      } else {
        print(
            "❌ UserDataProvider: Coin verisi alınamadı - HTTP ${response.statusCode}");
        print("❌ Yanıt: ${response.body}");
        // Hata durumunda mevcut coin state'ini değiştirmeyebiliriz veya hata state'i ayarlayabiliriz.
        // Şimdilik mevcut state'i koruyalım.
      }
    } catch (e, stackTrace) {
      print("❌ UserDataProvider: Coin çekme hatası: $e");
      // Hata durumunda mevcut state'i koruyalım.
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
