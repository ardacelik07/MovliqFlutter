import 'dart:convert';
import 'dart:math'; // min fonksiyonu için eklendi
// import 'dart:developer'; // log yerine print kullanacağız
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
    print('_fetchProducts started'); // print ile log
    final Uri uri = Uri.parse(ApiConfig.productsEndpoint);
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
}
