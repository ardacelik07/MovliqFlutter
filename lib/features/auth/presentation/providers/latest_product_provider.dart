import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/latest_product_model.dart';

// 1. Define the Notifier
class LatestProductNotifier extends AsyncNotifier<List<LatestProductModel>> {
  // Sabit olarak 5 ürün getirelim
  final int _count = 5;

  @override
  Future<List<LatestProductModel>> build() async {
    return _fetchLatestProducts();
  }

  Future<List<LatestProductModel>> _fetchLatestProducts() async {
    try {
      // Retrieve token
      final String? tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        throw Exception("Oturum açılmamış veya token alınamadı.");
      }

      final String token = tokenJson;
      if (token == null || token.isEmpty) {
        throw Exception("Geçersiz token.");
      }

      // Construct URL and Headers
      final Uri url = Uri.parse('${ApiConfig.baseUrl}/Products/latest/$_count');
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Make API call
      final response = await http.get(url, headers: headers).timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception("API isteği zaman aşımına uğradı (15 saniye)"));

      // Process response
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final List<LatestProductModel> products = data
            .map((item) =>
                LatestProductModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return products;
      } else {
        throw Exception(
            'Ürünler yüklenemedi: Sunucu Hatası ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      // Catch block automatically sets state to AsyncError
      // Rethrow to ensure AsyncValue.guard handles it
      rethrow;
    }
  }

  // Refresh method
  Future<void> refreshProducts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchLatestProducts());
  }
}

// 2. Define the Provider
final latestProductProvider =
    AsyncNotifierProvider<LatestProductNotifier, List<LatestProductModel>>(() {
  return LatestProductNotifier();
});
