import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_flutter_project/core/config/api_config.dart';
import 'package:my_flutter_project/features/auth/domain/models/product.dart';

part 'product_provider.g.dart';

@riverpod
class ProductNotifier extends _$ProductNotifier {
  @override
  Future<List<Product>> build() async {
    return _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final Uri uri = Uri.parse(ApiConfig.productsEndpoint);
    try {
      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Product> products =
            data.map((item) => Product.fromJson(item)).toList();
        return products;
      } else {
        // API'den hata durum kodu döndüğünde
        throw Exception(
            'Failed to load products. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Ağ hatası veya JSON parse hatası
      throw Exception('Failed to load products: $e');
    }
  }
}
