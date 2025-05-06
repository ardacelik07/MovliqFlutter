import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';
import '../config/api_config.dart';

// HTTP isteği sonuçlarını izleyen ve 401 hatası durumunda otomatik olarak logout eden sınıf
class HttpInterceptor {
  static NavigatorState? _navigator;
  static bool _isLoggingOut = false;
  static bool _isRefreshingToken = false;

  // Navigator'u ayarla
  static void setNavigator(NavigatorState navigator) {
    _navigator = navigator;
    print('✅ HttpInterceptor: NavigatorState başarıyla ayarlandı');
  }

  // Token hatasını işle - herhangi bir API sınıfından çağrılabilir
  static Future<void> handleTokenError() async {
    print('🚨 Token hatası tespit edildi (handleTokenError çağrıldı)');
    _handleUnauthorized();
  }

  // Yetkisiz erişim durumunda logout işlemini gerçekleştir
  static void _handleUnauthorized() async {
    if (_isLoggingOut) {
      print('⏳ Zaten logout işlemi devam ediyor, tekrar işlem yapılmıyor');
      return;
    }
    _isLoggingOut = true;

    try {
      print('🔑 Token siliniyor ve oturum kapatılıyor...');
      await StorageService.deleteToken();

      if (_navigator != null) {
        if (_navigator!.context.mounted) {
          print('🔄 Login ekranına yönlendiriliyor...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigator!.pushNamedAndRemoveUntil('/login', (route) => false);
          });
        } else {
          print('⚠️ Context geçerli değil, login ekranına yönlendirilemedi');
        }
      } else {
        print('⚠️ Navigator bulunamadı, login ekranına yönlendirilemedi');
      }
    } catch (e) {
      print('⚠️ Logout işlemi sırasında hata: $e');
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        _isLoggingOut = false;
      });
    }
  }

  // Access Token'ı headera ekle
  static Future<Map<String, String>> _getHeadersWithToken(
      Map<String, String>? originalHeaders) async {
    final Map<String, String> headers =
        Map<String, String>.from(originalHeaders ?? ApiConfig.headers);
    final String? accessToken = await StorageService.getToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  // Token yenileme işlemi
  static Future<bool> _refreshToken() async {
    if (_isRefreshingToken) {
      print('⏳ Token yenileme zaten deneniyor.');
      return false;
    }
    _isRefreshingToken = true;
    print('🔄 Token yenileme deneniyor...');

    try {
      final String? refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ Refresh token bulunamadı. Yenileme yapılamaz.');
        return false;
      }

      final http.Response response = await http.post(
        Uri.parse(ApiConfig.refreshTokenEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? newAccessToken = responseData['accessToken'] as String?;
        final String? newRefreshToken = responseData['refreshToken'] as String?;

        if (newAccessToken != null &&
            newAccessToken.isNotEmpty &&
            newRefreshToken != null &&
            newRefreshToken.isNotEmpty) {
          await StorageService.saveToken(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          print('✅ Token başarıyla yenilendi.');
          return true;
        } else {
          print('❌ Yenilenen tokenlar response içinde bulunamadı.');
          return false;
        }
      } else {
        print('❌ Token yenileme başarısız. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Token yenileme sırasında hata: $e');
      return false;
    } finally {
      _isRefreshingToken = false;
    }
  }

  // İstek öncesi access token kontrolü yap
  static Future<void> _checkAccessToken() async {
    final String? accessToken = await StorageService.getToken();
    if (accessToken == null || accessToken.isEmpty) {
      print('❌ Access Token bulunamadı. İstek yapılamaz.');
      throw Exception('Access Token bulunamadı');
    }
  }

  // Genel istek sarmalayıcı
  static Future<http.Response> _requestWrapper(
    Future<http.Response> Function(Map<String, String> headers) makeRequest,
    Map<String, String>? originalHeaders, {
    bool isRetry = false,
  }) async {
    try {
      if (!isRetry) {
        await _checkAccessToken();
      }
      final Map<String, String> headersWithToken =
          await _getHeadersWithToken(originalHeaders);
      http.Response response = await makeRequest(headersWithToken);

      if (response.statusCode == 401) {
        if (isRetry || _isRefreshingToken) {
          print('🚨 HTTP 401 (Retry veya Refreshing). Oturum sonlandırılıyor.');
          _handleUnauthorized();
        } else {
          print('🚨 HTTP 401. Token yenileme denenecek...');
          final bool refreshed = await _refreshToken();
          if (refreshed) {
            print('✅ Token yenilendi. İstek tekrarlanıyor...');
            return _requestWrapper(makeRequest, originalHeaders, isRetry: true);
          } else {
            print('❌ Token yenileme başarısız. Oturum sonlandırılıyor.');
            _handleUnauthorized();
          }
        }
      }
      return response;
    } catch (e) {
      print('❌ HTTP request wrapper hatası: $e');
      _checkForTokenError(e);
      rethrow;
    }
  }

  // HTTP GET isteği yap ve intercept et
  static Future<http.Response> get(Uri url,
      {Map<String, String>? headers}) async {
    return _requestWrapper(
      (headersWithToken) => http.get(url, headers: headersWithToken),
      headers,
    );
  }

  // HTTP POST isteği yap ve intercept et
  static Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    return _requestWrapper(
      (headersWithToken) => http.post(url,
          headers: headersWithToken, body: body, encoding: encoding),
      headers,
    );
  }

  // HTTP PUT isteği yap ve intercept et
  static Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    return _requestWrapper(
      (headersWithToken) => http.put(url,
          headers: headersWithToken, body: body, encoding: encoding),
      headers,
    );
  }

  // HTTP DELETE isteği yap ve intercept et
  static Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    return _requestWrapper(
      (headersWithToken) => http.delete(url,
          headers: headersWithToken, body: body, encoding: encoding),
      headers,
    );
  }

  // Hata mesajını kontrol et - token hatası içeriyorsa logout yap
  static void _checkForTokenError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('token') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('auth') ||
        errorMessage.contains('format')) {
      print(
          '🚨 Token ile ilgili bir hata tespit edildi (_checkForTokenError): $errorMessage');
      _handleUnauthorized();
    }
  }
}
