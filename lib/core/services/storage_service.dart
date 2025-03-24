import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _tokenKey = 'auth_token';

  // SharedPreferences erişiminde sorun olmaması için güvenli erişim sağlayacak yardımcı metod
  static Future<SharedPreferences?> _getPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs;
    } catch (e) {
      print('❌ StorageService: SharedPreferences erişim hatası: $e');
      return null;
    }
  }

  // Token'ı kaydet (kalıcı olarak)
  static Future<bool> saveToken(String token) async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        print('❌ StorageService: SharedPreferences erişilemedi');
        return false;
      }

      await prefs.setString(_tokenKey, token);
      print('✅ StorageService: Token kalıcı olarak kaydedildi');
      print('📝 Kaydedilen Token: $token');
      return true;
    } catch (e) {
      print('❌ StorageService: Token kaydedilirken hata oluştu: $e');
      return false;
    }
  }

  // Token'ı getir (kalıcı depolamadan)
  static Future<String?> getToken() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        print('❌ StorageService: SharedPreferences erişilemedi');
        return null;
      }

      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        print('✅ StorageService: Token başarıyla alındı');
        return token;
      } else {
        print('⚠️ StorageService: Token bulunamadı veya boş');
        return null;
      }
    } catch (e) {
      print('❌ StorageService: Token alınırken hata oluştu: $e');
      return null;
    }
  }

  // Token'ı sil (logout için)
  static Future<bool> deleteToken() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        print('❌ StorageService: SharedPreferences erişilemedi');
        return false;
      }

      // Tüm token verilerini temizle
      await prefs.remove(_tokenKey);
      print('✅ StorageService: Token silindi');

      // Token kontrolü yaparak silme işleminin başarılı olup olmadığını doğrula
      final tokenCheck = prefs.getString(_tokenKey);
      if (tokenCheck == null) {
        print('✅ StorageService: Token başarıyla silindi, doğrulandı');
        return true;
      } else {
        print('⚠️ StorageService: Token silinemedi, hala mevcut');
        return false;
      }
    } catch (e) {
      print('❌ StorageService: Token silinirken hata oluştu: $e');
      return false;
    }
  }

  // Tüm uygulama verilerini temizle (sorun durumunda)
  static Future<bool> clearAllData() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        print('❌ StorageService: SharedPreferences erişilemedi');
        return false;
      }

      await prefs.clear();
      print('✅ StorageService: Tüm uygulama verileri temizlendi');
      return true;
    } catch (e) {
      print('❌ StorageService: Veri temizleme hatası: $e');
      return false;
    }
  }

  // Token var mı kontrol et
  static Future<bool> hasToken() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        print('❌ StorageService: SharedPreferences erişilemedi');
        return false;
      }

      final token = prefs.getString(_tokenKey);
      bool hasValidToken = token != null && token.isNotEmpty;

      print(hasValidToken
          ? '✅ StorageService: Geçerli token bulundu'
          : '⚠️ StorageService: Token bulunamadı');

      // Token'ın format kontrolü
      if (hasValidToken) {
        try {
          final tokenData = jsonDecode(token!);
          if (tokenData is Map<String, dynamic> &&
              tokenData.containsKey('token')) {
            print('✅ StorageService: Token formatı doğru');
          } else {
            print('⚠️ StorageService: Token formatı beklenmeyen yapıda');
          }
        } catch (e) {
          print('⚠️ StorageService: Token JSON formatında değil: $e');
          // JSON formatında olmasa bile token var
        }
      }

      return hasValidToken;
    } catch (e) {
      print('❌ StorageService: Token kontrolü sırasında hata oluştu: $e');
      return false;
    }
  }
}
