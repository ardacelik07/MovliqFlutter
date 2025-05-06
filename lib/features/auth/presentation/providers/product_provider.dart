import 'dart:convert';
import 'dart:math'; // min fonksiyonu için eklendi
// import 'dart:developer'; // log yerine print kullanacağız
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:async'; // For Timeout
import 'package:flutter/foundation.dart'; // For @immutable

import 'package:my_flutter_project/core/config/api_config.dart';
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:my_flutter_project/core/services/storage_service.dart'; // StorageService importu eklendi

part 'product_provider.g.dart';

// --- API Yanıt Modelleri (Taşınmalı: örn. lib/features/auth/domain/models/acquired_coupon_response.dart) ---
class AcquiredCouponResponse {
  final AcquiredCoupon? acquiredCoupon;
  final String? productName;
  final String? productUrl;
  final int? productId;

  AcquiredCouponResponse({
    required this.acquiredCoupon,
    required this.productName,
    required this.productUrl,
    required this.productId,
  });

  factory AcquiredCouponResponse.fromJson(Map<String, dynamic> json) {
    print("Decoding AcquiredCouponResponse: $json"); // Debug log
    return AcquiredCouponResponse(
      acquiredCoupon: AcquiredCoupon.fromJson(
          json['acquiredCoupon'] as Map<String, dynamic>? ?? {}),
      productName: json['productName'] as String? ?? '',
      productUrl: json['productUrl'] as String? ?? '',
      productId: json['productId'] as int? ?? 0,
    );
  }
  Map<String, dynamic> toJson() => {
        'acquiredCoupon': acquiredCoupon?.toJson() ?? {},
        'productName': productName,
        'productUrl': productUrl,
        'productId': productId,
      };
}

class AcquiredCoupon {
  final int? id;
  final String? code;
  final bool? isActive; // JSON'da isActive, modelde isActive kullandım
  final String? expirationDate;
  final int? maxUses;
  final int? usesCount;
  final String? createdAt;

  AcquiredCoupon({
    required this.id,
    required this.code,
    required this.isActive,
    required this.expirationDate,
    required this.maxUses,
    required this.usesCount,
    required this.createdAt,
  });

  factory AcquiredCoupon.fromJson(Map<String, dynamic> json) {
    print("Decoding AcquiredCoupon: $json"); // Debug log
    return AcquiredCoupon(
      id: json['id'] as int,
      code: json['code'] as String,
      isActive: json['isActive'] as bool, // JSON'daki anahtarla eşleşmeli
      expirationDate: json['expirationDate'] as String?,
      maxUses: json['maxUses'] as int?,
      usesCount: json['usesCount'] as int,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'isActive': isActive,
        'expirationDate': expirationDate,
        'maxUses': maxUses,
        'usesCount': usesCount,
        'createdAt': createdAt,
      };
}
// --- Model Sonu ---

@Riverpod(keepAlive: false)
class ProductNotifier extends _$ProductNotifier {
  @override
  Future<List<Product>> build() async {
    print('ProductNotifier build started'); // print ile log
    try {
      final result = await _fetchProducts();
      print('ProductNotifier build finished successfully');
      return result;
    } catch (e, stackTrace) {
      print(
          'Error during ProductNotifier build: $e\n$stackTrace'); // print ile log
      rethrow; // Hatayı tekrar fırlat
    }
  }

  Future<List<Product>> _fetchProducts() async {
    final isMovliqProduct = false;
    print('_fetchProducts started'); // print ile log
    final Uri uri = Uri.parse(
        '${ApiConfig.baseUrl}/Products/GetProductsByUniqueID/$isMovliqProduct');
    try {
      print('Attempting to fetch products from: $uri');
      final response = await http.get(uri, headers: ApiConfig.headers);

      print('API Response Status Code: ${response.statusCode}');
      print(
          'API Response Body length: ${response.body.length}'); // print ile log

      if (response.statusCode == 200) {
        print('Status code is 200, attempting to decode JSON...');
        final List<dynamic> data = json.decode(response.body);
        print(
            'JSON decoded successfully, attempting to map to Product objects...');

        // API yanıtını tamamen yazdıralım, tam olarak ne geldiğini görelim
        print('FULL API RESPONSE: ${response.body}');

        // Data before mapping, up to 500 chars
        print(
            'Data before mapping: ${data.toString().substring(0, min(data.toString().length, 500))}...');

        final List<Product> products =
            data.map((item) => Product.fromJson(item)).toList();
        print('Products mapped successfully!');
        return products;
      } else {
        print(
            'API Error: Status Code ${response.statusCode}, Body: ${response.body}'); // print ile log
        throw Exception(
            'Failed to load products. Status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error caught in _fetchProducts: $e'); // print ile log
      print('Stack trace: $stackTrace'); // print ile log
      throw Exception('Failed to load products due to an error: $e');
    }
  }

  // Manuel olarak verileri yenilemek için metot
  Future<void> refreshProducts() async {
    print('Manually refreshing products data');
    state = const AsyncValue.loading();
    try {
      final products = await _fetchProducts();
      state = AsyncValue.data(products);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // Fetch Movliq product by unique ID
  Future<Product> fetchMovliqProduct() async {
    final isMovliqProduct = true;
    print('fetchMovliqProduct started');
    final Uri uri = Uri.parse(
        '${ApiConfig.baseUrl}/Products/GetProductsByUniqueID/$isMovliqProduct');
    try {
      print('Attempting to fetch Movliq product from: $uri');
      final response = await http.get(uri, headers: ApiConfig.headers);

      print('API Response Status Code: ${response.statusCode}');
      print('API Response Body length: ${response.body.length}');

      if (response.statusCode == 200) {
        print('Status code is 200, attempting to decode JSON...');
        final dynamic data = json.decode(response.body);
        print('JSON decoded successfully');

        // API response debug
        print('FULL API RESPONSE: ${response.body}');

        if (data is List && data.isNotEmpty) {
          final Product product = Product.fromJson(data[0]);
          print('Movliq product mapped successfully!');
          return product;
        } else {
          throw Exception('No Movliq products found in the response');
        }
      } else {
        print(
            'API Error: Status Code ${response.statusCode}, Body: ${response.body}');
        throw Exception(
            'Failed to load Movliq product. Status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error caught in fetchMovliqProduct: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load Movliq product due to an error: $e');
    }
  }

  // Ürün Satın Alma Metodu
  Future<AcquiredCouponResponse> purchaseProduct(int productId) async {
    // Metoda gelen ID'yi logla
    print('purchaseProduct called with productId: $productId');

    final Uri uri =
        Uri.parse('${ApiConfig.baseUrl}/Products/purchase/$productId');
    // Oluşturulan tam URL'i logla
    print('Requesting POST to: ${uri.toString()}');

    // Token'ı al (Doğru null kontrolü ile)
    final tokenJson = await StorageService.getToken();
    if (tokenJson == null) {
      print('Error: No token found in storage.');
      throw Exception('Lütfen giriş yapın.');
    }
    final String token = tokenJson;
    if (token == null) {
      print('Error: Token key not found in stored JSON or token is null.');
      throw Exception('Giriş bilgileri alınamadı. Lütfen tekrar giriş yapın.');
    }
    // print('Token: $token'); // Token'ı loglamaya gerek yok artık

    // Header'ları oluştur
    final Map<String, String> headers = {
      ...ApiConfig.headers,
      'Authorization': 'Bearer $token',
    };

    // print('Headers with token: $headers'); // Header'ları loglamaya gerek yok artık

    try {
      final response = await http.post(
        uri,
        headers: headers,
      );

      print('Purchase API Response Status Code: ${response.statusCode}');
      print('Purchase API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Başarılı durum kodları
        print('Purchase successful, decoding response...');
        // Yanıt boş değilse decode et
        if (response.body.isNotEmpty) {
          final Map<String, dynamic> data = json.decode(response.body);
          return AcquiredCouponResponse.fromJson(data);
        } else {
          // Yanıt boşsa ama başarılıysa (200 OK), belki kuponsuz bir başarı durumu?
          // Bu senaryo API tasarımına bağlı, şimdilik hata fırlatabiliriz.
          print('Purchase successful but response body is empty.');
          throw Exception('Purchase successful but no coupon data received.');
        }
      } else if (response.statusCode == 400) {
        // Örnek: Yetersiz Bakiye vb.
        print('Purchase failed (400): ${response.body}');
        // API'den gelen hata mesajını göstermek daha iyi olabilir
        // Yanıtın JSON olup olmadığını kontrol et
        Map<String, dynamic>? errorData;
        try {
          errorData = json.decode(response.body);
        } catch (_) {
          errorData = null; // JSON değilse null ata
        }
        final String errorMessage =
            errorData?['message'] ?? response.body; // API'ye göre ayarla
        throw Exception('Satın alma başarısız: $errorMessage');
      } else if (response.statusCode == 401) {
        // Özel 401 kontrolü
        print(
            'Purchase failed (401): Unauthorized. Token might be invalid or expired.');
        throw Exception(
            'Oturumunuz zaman aşımına uğradı veya geçersiz. Lütfen tekrar giriş yapın.');
      } else {
        print(
            'Purchase failed with status code ${response.statusCode}: ${response.body}');
        throw Exception(
            'Failed to purchase product. Status code: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error caught in purchaseProduct: $e');
      print('Stack trace: $stackTrace');
      // Yakalanan Exception'ı tekrar fırlatmak veya daha kullanıcı dostu bir mesaj vermek
      if (e is Exception) {
        rethrow; // Zaten anlamlı bir Exception ise tekrar fırlat
      }
      throw Exception('Satın alma sırasında bir hata oluştu: $e');
    }
  }
}

// Create a provider for Movliq product with autoDispose to refresh on each access
final movliqProductProvider = FutureProvider.autoDispose<Product>((ref) async {
  final productNotifier = ref.watch(productNotifierProvider.notifier);
  return await productNotifier.fetchMovliqProduct();
});

// --- Provider for fetching a SINGLE product by ID ---

// Notifier for fetching product details by ID
// Use AutoDisposeAsyncNotifier if the state should reset when not listened to
class ProductDetailNotifier extends AutoDisposeAsyncNotifier<Product> {
  // Store the ID for which details are being fetched
  int _currentProductId = -1; // Initialize with an invalid ID

  @override
  Future<Product> build() async {
    // Initially, we don't have an ID, so we can't fetch.
    // We need a mechanism to pass the ID. A common way without family
    // is to have a method like `fetchProductDetails(id)` called from UI.
    // The initial build can return a loading/default state or throw.
    // Let's throw to indicate it needs initialization via fetchProductDetails.
    print(
        "📦 ProductDetailProvider: Initial build - Waiting for ID via fetchProductDetails.");
    // Return a future that never completes to keep it in loading state initially.
    // fetchProductDetails will eventually update the state with data or error.
    return Completer<Product>().future;
  }

  // Method to fetch details for a specific ID
  Future<void> fetchProductDetails(int productId) async {
    // If already fetching for this ID, do nothing
    if (state is AsyncLoading && _currentProductId == productId) return;

    _currentProductId = productId;
    print(
        "📦 ProductDetailProvider: Fetching details for product ID: $productId");
    state = const AsyncValue.loading(); // Set loading state

    state = await AsyncValue.guard(() async {
      // Optional: Check if we already fetched this product and it's in a data state
      // Note: This basic cache doesn't handle expiration or forced refresh well.
      // if (state.hasValue && state.value?.id == productId) {
      //   print("📦 ProductDetailProvider: Using cached product for ID $productId");
      //   return state.value!;
      // }

      final String? tokenJson = await StorageService.getToken();
      if (tokenJson == null) throw Exception("Token bulunamadı");

      final String token = tokenJson;
      if (token == null || token.isEmpty) throw Exception("Geçersiz token");

      final Uri url = Uri.parse('${ApiConfig.baseUrl}/Products/$productId');
      print("📦 ProductDetailProvider: API URL: $url");
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      print(
          "📦 ProductDetailProvider: API response for ID $productId - Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        // IMPORTANT: Parse using the correct Product.fromJson
        final Product product = Product.fromJson(data);
        print(
            "📦 ProductDetailProvider: Product details fetched successfully for ID $productId");
        return product;
      } else {
        print(
            '❌ ProductDetailProvider: Failed to load product details for ID $productId: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception(
            'Ürün detayları yüklenemedi: Sunucu Hatası ${response.statusCode}');
      }
    });
  }
}

// Define the provider
// Use AutoDispose to reset state when the screen is left
final productDetailProvider =
    AsyncNotifierProvider.autoDispose<ProductDetailNotifier, Product>(() {
  return ProductDetailNotifier();
});
