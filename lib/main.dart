import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/tabs.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized

  // Hata yakalama mekanizması ekle
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ Flutter Hatası: ${details.exception}');
    print('❌ Stack Trace: ${details.stack}');
    FlutterError.presentError(details);
  };

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // initState'de async işlem çağırmak için Future.microtask kullan
    Future.microtask(() => _checkLoginStatus());
  }

  Future<void> _checkLoginStatus() async {
    print('📱 Uygulama başlatılıyor - Token kontrolü yapılıyor');

    try {
      // Token var mı kontrol et
      final hasToken = await StorageService.hasToken();
      print('🔍 Token kontrolü sonucu: $hasToken');

      // Token mevcutsa
      if (hasToken) {
        try {
          // Token içeriğini al
          final tokenJson = await StorageService.getToken();
          if (tokenJson == null || tokenJson.isEmpty) {
            print('⚠️ Ana uygulama: Token boş veya null');
            _updateState(false);
            return;
          }

          // Token formatını kontrol et
          try {
            final tokenData = jsonDecode(tokenJson);
            if (tokenData is Map<String, dynamic> &&
                tokenData.containsKey('token')) {
              print(
                  '✅ Ana uygulama: Token doğrulandı, giriş yapılmış kullanıcı.');
              _updateState(true);
            } else {
              print('⚠️ Ana uygulama: Token formatı geçersiz: $tokenData');
              _updateState(false);
            }
          } catch (e) {
            print('⚠️ Ana uygulama: Token JSON formatında değil: $e');

            // Token ayrıştırma hatası, ham string olabilir, doğrudan kullanmayı dene
            if (tokenJson.isNotEmpty) {
              print('🔄 Ana uygulama: Token ham string olarak kabul ediliyor');
              _updateState(true);
            } else {
              _updateState(false);
            }
          }
        } catch (e) {
          print('❌ Ana uygulama: Token işlenirken hata: $e');
          _updateState(false);
        }
      } else {
        _updateState(false);
      }
    } catch (e) {
      print('❌ Ana uygulama: Giriş durumu kontrolünde hata: $e');
      _updateState(false);
    }
  }

  // State güncelleme işlevini ayrı bir metoda çıkar
  void _updateState(bool isLoggedIn) {
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basitleştirilmiş conditional widget oluşturma
    Widget homeWidget;

    if (!_isInitialized) {
      homeWidget = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFC4FF62),
          ),
        ),
      );
    } else {
      homeWidget = _isLoggedIn ? const TabsScreen() : const LoginScreen();
    }

    // Tüm uygulamayı WillPopScope ile sarmalıyoruz
    return WillPopScope(
      onWillPop: () async {
        // Kullanıcı giriş yapmışsa ve geri tuşuna basarsa
        if (_isLoggedIn) {
          print("⚠️ Ana uygulama: Geri tuşu basıldı, engelleniyor");
          // Geri tuşunu engelle - TabsScreen kendi WillPopScope'unu işleyecek
          return false;
        }
        // Giriş yapmamışsa normal geri davranışına izin ver
        return true;
      },
      child: MaterialApp(
        title: 'Movliq',
        theme: AppTheme.lightTheme,
        home: homeWidget,
      ),
    );
  }
}
