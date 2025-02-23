class StorageService {
  static String? _token;

  // Token'ı kaydet
  static Future<void> saveToken(String token) async {
    _token = token;
    print('Token saved: $token');
  }

  // Token'ı getir
  static Future<String?> getToken() async {
    return _token;
  }

  // Token'ı sil (logout için)
  static Future<void> deleteToken() async {
    _token = null;
    print('Token deleted');
  }

  // Token var mı kontrol et
  static Future<bool> hasToken() async {
    return _token != null;
  }
}
