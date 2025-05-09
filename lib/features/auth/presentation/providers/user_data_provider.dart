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

      final String? accessToken = await StorageService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        state = AsyncValue.error("Token bulunamadı", StackTrace.current);
        print("❌ UserDataProvider: Token bulunamadı");
        return;
      }

      // HttpInterceptor token'ı otomatik olarak ekleyecektir.
      final response = await HttpInterceptor.get(
        Uri.parse('${ApiConfig.baseUrl}/User/profile'),
        // headers: { 'Content-Type': 'application/json' }, // Gerekirse sadece Content-Type
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
      await fetchUserData();
      if (state.value == null || state.hasError) return;
    }

    try {
      print("💰 Fetching coins...");
      final String? accessToken = await StorageService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        print("❌ UserDataProvider: Token bulunamadı (fetchCoins)");
        return;
      }

      // HttpInterceptor token'ı otomatik olarak ekleyecektir.
      final response = await HttpInterceptor.get(
        Uri.parse('${ApiConfig.baseUrl}/User/my-coins'), // Yeni endpoint
        // headers: { 'Accept': 'application/json' }, // Gerekirse sadece Accept
      );

      print(
          "💰 UserDataProvider: Coins API yanıtı - Status ${response.statusCode}");

      if (response.statusCode == 200) {
        // API'nin sadece sayıyı mı yoksa { "coins": sayı } şeklinde mi döndüğünü kontrol et
        final dynamic responseData = jsonDecode(response.body);
        print(
            "📊 [Debug] Raw API Response for coins: $responseData, Type: ${responseData.runtimeType}"); // Debug Log 1: Ham yanıtı gör
        double coins = 0.0;
        if (responseData is int) {
          print(
              "🔢 [Debug] API returned int, converting to double."); // Debug Log 2a
          coins = responseData.toDouble();
        } else if (responseData is double) {
          print("🔢 [Debug] API returned double directly."); // Debug Log 2b
          coins = responseData;
        } else if (responseData is Map<String, dynamic> &&
            responseData.containsKey('coins')) {
          final coinValue = responseData['coins'];
          print(
              "🗺️ [Debug] API returned map, extracting 'coins': $coinValue, Type: ${coinValue.runtimeType}"); // Debug Log 2c
          coins = (coinValue as num?)?.toDouble() ?? 0.0;
        } else {
          // Beklenmedik format, logla ve 0 ata
          print(
              "❌ UserDataProvider: Beklenmedik coin yanıt formatı: ${response.body}");
        }

        print(
            "✅ UserDataProvider: Parsed coins: $coins, Type: ${coins.runtimeType}"); // Debug Log 3: Parse edilen değeri ve tipini gör

        // Mevcut state'i güncelle, sadece coins değerini değiştir
        if (state.value != null) {
          print(
              "🔄 [Debug] Current state exists. Calling copyWith..."); // Debug Log 4
          final updatedModel = state.value!.copyWith(coins: coins);
          print(
              "✨ [Debug] Updated model coins: ${updatedModel.coins}, Type: ${updatedModel.coins.runtimeType}"); // Debug Log 5: copyWith sonrası tipi gör
          state = AsyncValue.data(updatedModel);
          print("✅ UserDataProvider: State (coins) güncellendi.");
        } else {
          print(
              "⚠️ [Debug] Current state is null. Cannot update coins only."); // Debug Log 6
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

  // Kullanıcı profilini API'de güncelle
  Future<bool> updateUserProfile(UserDataModel updatedData) async {
    if (state.value == null) {
      print("❌ UserDataNotifier: Güncellenecek mevcut kullanıcı verisi yok.");
      return false; // Veya fetchUserData çağırıp tekrar denenebilir
    }

    // Mevcut state'i alıp loading state'ine geçirelim (UI'da göstermek için)
    final previousState = state;
    state = const AsyncValue.loading();

    try {
      final String? accessToken = await StorageService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        print("❌ UserDataNotifier: Token bulunamadı (updateUserProfile).");
        state = AsyncValue.error("Token bulunamadı", StackTrace.current);
        return false;
      }

      // HttpInterceptor token'ı otomatik olarak ekleyecektir.
      // currentToken değişkenine gerek kalmadı.
      final response = await HttpInterceptor.put(
        Uri.parse(ApiConfig.updateProfileEndpoint),
        // headers: { 'Content-Type': 'application/json' }, // Gerekirse sadece Content-Type
        body: jsonEncode(updatedData.toJson()),
      );

      print(
          "🔄 UserDataNotifier: Update API yanıtı - Status ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBodyMap =
            jsonDecode(response.body) as Map<String, dynamic>;
        // API'nizin yeni tokenları nasıl döndürdüğüne bağlı olarak bu anahtarları güncelleyin
        final String? newAccessToken =
            responseBodyMap['accessToken'] as String?;
        final String? newRefreshToken =
            responseBodyMap['refreshToken'] as String?;

        if (newAccessToken != null &&
            newAccessToken.isNotEmpty &&
            newRefreshToken != null &&
            newRefreshToken.isNotEmpty) {
          await StorageService.saveToken(
            accessToken: newAccessToken, // SAF STRING
            refreshToken: newRefreshToken, // SAF STRING
          );
          print("✅ UserDataNotifier: Yeni tokenlar başarıyla kaydedildi.");
          state = AsyncValue.data(updatedData);
          print(
              "✅ UserDataNotifier: Profil başarıyla güncellendi (state güncellendi).");
          return true;
        } else {
          print(
              "❌ UserDataNotifier: Yanıtta yeni tokenlar (accessToken, refreshToken) bulunamadı veya boş.");
          // Yeni token gelmediyse, belki sadece başarılı olduğunu belirtmek yeterlidir
          // ve mevcut tokenlar geçerliliğini korur. Bu API tasarımına bağlıdır.
          // Şimdilik, token gelmezse de işlemi başarılı sayıp eski state'e dönmeyelim,
          // çünkü profil sunucuda güncellenmiş olabilir.
          state = AsyncValue.data(updatedData); // Profili güncelledik.
          print("✅ UserDataNotifier: Profil güncellendi (yeni token dönmedi).");
          return true; // Tokenlar yenilenmese de profil güncellendi.
        }
      } else {
        print(
            "❌ UserDataNotifier: Profil güncellenemedi - HTTP ${response.statusCode}");
        print("❌ Yanıt: ${response.body}");
        // Hata mesajını state'e yansıt
        String errorMessage = "Profil güncellenemedi: ${response.statusCode}";
        try {
          // API'den gelen hata mesajını parse etmeyi dene
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody.containsKey('message')) {
            errorMessage = errorBody['message'];
          } else if (errorBody is String) {
            errorMessage = errorBody;
          }
        } catch (_) {
          // JSON parse edilemezse veya format farklıysa, ham yanıtı kullan
          errorMessage = response.body;
        }

        state = AsyncValue.error(errorMessage, StackTrace.current);
        return false; // Başarısız
      }
    } catch (e, stackTrace) {
      print("❌ UserDataNotifier: Profil güncelleme hatası: $e");
      state = AsyncValue.error(e, stackTrace);
      return false; // Başarısız
    }
  }
}

// Kullanıcı streak sayısını getiren provider
final userStreakProvider = FutureProvider<int>((ref) async {
  try {
    final String? accessToken = await StorageService.getToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Token bulunamadı');
    }

    // HttpInterceptor token'ı otomatik olarak ekleyecektir.
    final response = await HttpInterceptor.get(
      Uri.parse(ApiConfig.userStreakTrackEndpoint),
      // headers: { 'Content-Type': 'application/json' }, // Gerekirse sadece Content-Type
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
