import 'dart:convert'; // For jsonDecode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/coupon_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/config/api_config.dart';

// 1. Define the Notifier
class CouponNotifier extends AsyncNotifier<List<CouponModel>> {
  @override
  Future<List<CouponModel>> build() async {
    // build itself calls _fetchCoupons, no need to set loading state here
    return _fetchCoupons();
  }

  // Method to fetch data directly using http
  Future<List<CouponModel>> _fetchCoupons() async {
    // No need to set loading state here; AsyncNotifier/AsyncValue.guard handles it

    try {
      // Retrieve token
      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        state = AsyncValue.error("Token bulunamadı", StackTrace.current);
        print("❌ UserDataProvider: Token bulunamadı");
        return [];
      }

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      // Construct URL and Headers
      // Using the endpoint from your edits
      final Uri url =
          Uri.parse('${ApiConfig.baseUrl}/Products/my-acquired-coupons');
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Use the retrieved token
      };

      // Make API call
      final response = await http.get(url, headers: headers);

      // Process response
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final List<CouponModel> coupons = data
            .map((item) => CouponModel.fromJson(item as Map<String, dynamic>))
            .toList();
        print("🎫 CouponProvider: ${coupons.length} adet kupon alındı");
        // Return data - AsyncNotifier updates state automatically
        return coupons;
      } else {
        // Handle API errors (non-200 status)
        print(
            'Failed to load coupons: Status code ${response.statusCode}, Body: ${response.body}');
        // Throw exception, let the catch block handle the state update
        throw Exception(
            'Kuponlar yüklenemedi: Sunucu Hatası ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      // Catch all errors (token retrieval, network, parsing, API errors)
      print('Error fetching coupons: $e');
      // Update the state to reflect the error - This is crucial for the UI
      state = AsyncValue.error(e, stackTrace);
      // Return empty list when state is set to error, so UI doesn't break waiting for data
      return [];
    }
  }

  // Refresh method remains the same, using AsyncValue.guard
  Future<void> refreshCoupons() async {
    state = const AsyncValue.loading();
    // AsyncValue.guard will automatically handle setting the state
    // to data or error based on the result of _fetchCoupons
    state = await AsyncValue.guard(() => _fetchCoupons());
  }
}

// 2. Define the Provider
final couponProvider =
    AsyncNotifierProvider<CouponNotifier, List<CouponModel>>(() {
  return CouponNotifier();
});
