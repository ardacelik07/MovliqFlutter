import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';

// HTTP isteği sonuçlarını izleyen ve 401 hatası durumunda otomatik olarak logout eden sınıf
class HttpInterceptor {
  static NavigatorState? _navigator;
  static bool _isLoggingOut = false;

  // Navigator'u ayarla
  static void setNavigator(NavigatorState navigator) {
    _navigator = navigator;
    print('✅ HttpInterceptor: NavigatorState başarıyla ayarlandı');
  }

  // HTTP yanıtını kontrol et
  static void checkResponse(http.Response response) {
    // 401 Unauthorized hatası varsa
    if (response.statusCode == 401) {
      print('🚨 HTTP 401 Unauthorized hatası tespit edildi');
      _handleUnauthorized();
    }
  }

  // Token hatasını işle - herhangi bir API sınıfından çağrılabilir
  static Future<void> handleTokenError() async {
    print('🚨 Token hatası tespit edildi');
    _handleUnauthorized();
  }

  // Yetkisiz erişim durumunda logout işlemini gerçekleştir
  static void _handleUnauthorized() async {
    // Eğer zaten logout işlemi yapılıyorsa, tekrar yapma
    if (_isLoggingOut) {
      print('⏳ Zaten logout işlemi devam ediyor, tekrar işlem yapılmıyor');
      return;
    }

    _isLoggingOut = true;

    try {
      print('🔑 Token siliniyor ve oturum kapatılıyor...');
      await StorageService.deleteToken();

      // Login ekranına yönlendir
      if (_navigator != null) {
        if (_navigator!.context.mounted) {
          print('🔄 Login ekranına yönlendiriliyor...');

          // WidgetsBinding ile UI thread'inde işlem yap
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

  // HTTP GET isteği yap ve intercept et
  static Future<http.Response> get(Uri url,
      {Map<String, String>? headers}) async {
    try {
      // İstek öncesi token kontrolü
      await _checkToken();

      final response = await http.get(url, headers: headers);
      checkResponse(response);
      return response;
    } catch (e) {
      print('❌ HTTP GET isteği sırasında hata: $e');
      _checkForTokenError(e);
      rethrow;
    }
  }

  // HTTP POST isteği yap ve intercept et
  static Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    try {
      // İstek öncesi token kontrolü
      await _checkToken();

      final response = await http.post(url,
          headers: headers, body: body, encoding: encoding);
      checkResponse(response);
      return response;
    } catch (e) {
      print('❌ HTTP POST isteği sırasında hata: $e');
      _checkForTokenError(e);
      rethrow;
    }
  }

  // HTTP PUT isteği yap ve intercept et
  static Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    try {
      // İstek öncesi token kontrolü
      await _checkToken();

      final response =
          await http.put(url, headers: headers, body: body, encoding: encoding);
      checkResponse(response);
      return response;
    } catch (e) {
      print('❌ HTTP PUT isteği sırasında hata: $e');
      _checkForTokenError(e);
      rethrow;
    }
  }

  // HTTP DELETE isteği yap ve intercept et
  static Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    try {
      // İstek öncesi token kontrolü
      await _checkToken();

      final response = await http.delete(url,
          headers: headers, body: body, encoding: encoding);
      checkResponse(response);
      return response;
    } catch (e) {
      print('❌ HTTP DELETE isteği sırasında hata: $e');
      _checkForTokenError(e);
      rethrow;
    }
  }

  // İstek öncesi token kontrolü yap
  static Future<void> _checkToken() async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null || tokenJson.isEmpty) {
        print('❌ Token bulunamadı, istek yapılamaz');
        throw Exception('Token bulunamadı');
      }

      try {
        final tokenData = jsonDecode(tokenJson);
        if (!tokenData.containsKey('token') ||
            tokenData['token'] == null ||
            tokenData['token'].isEmpty) {
          print('❌ Token geçersiz format içeriyor');
          throw Exception('Token geçersiz formatla kaydedilmiş');
        }
      } catch (e) {
        print('❌ Token parse edilemiyor: $e');
        throw Exception('Token parse hatası: $e');
      }
    } catch (e) {
      print('❌ Token kontrolü sırasında hata: $e');
      _handleUnauthorized();
      throw e;
    }
  }

  // Hata mesajını kontrol et - token hatası içeriyorsa logout yap
  static void _checkForTokenError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('token') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('401') ||
        errorMessage.contains('auth') ||
        errorMessage.contains('format')) {
      _handleUnauthorized();
    }
  }
}
