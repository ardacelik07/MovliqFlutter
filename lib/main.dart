import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/tabs.dart'; // HomePage yerine TabsScreen kullanacağız
import 'core/services/storage_service.dart';
import 'core/services/http_interceptor.dart';
import 'dart:convert';
import 'features/auth/presentation/providers/user_data_provider.dart'; // Import userDataProvider

// Global navigator anahtarı
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding
      .ensureInitialized(); // Asenkron işlemleri başlatmak için

  // HttpInterceptor'a NavigatorKey'i daha sonra atayacağız
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Uygulama başladıktan ve route'lar hazır olduktan sonra navigatorKey mevcut olacak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        HttpInterceptor.setNavigator(navigatorKey.currentState!);
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    try {
      final bool hasToken = await StorageService.hasToken();

      if (hasToken) {
        final tokenJson = await StorageService.getToken();
        if (tokenJson == null) {
          // Token var ama okunamıyorsa sil
          await StorageService.deleteToken();
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
          return;
        }

        try {
          // Token'ı parse etmeyi dene
          final tokenData = jsonDecode(tokenJson);
          if (!tokenData.containsKey('token') || tokenData['token'] == null) {
            // Token geçersizse sil
            await StorageService.deleteToken();
            setState(() {
              _isLoggedIn = false;
              _isLoading = false;
            });
            return;
          }
          // Token geçerli, kullanıcı giriş yapmış durumda
          setState(() {
            _isLoggedIn = true; // Set logged in first
            _isLoading = false;
          });
          // Kullanıcı giriş yapmışsa veriyi fetch et
          ref
              .read(userDataProvider.notifier)
              .fetchUserData(); // Fetch user data
          return; // Return after successful login check and data fetch initiation
        } catch (e) {
          // Parse hatası varsa tokeni sil
          print('Token parse hatası: $e');
          await StorageService.deleteToken();
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
          return;
        }
      } else {
        // No token found, user is not logged in
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Login durumu kontrol edilirken hata: $e');
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movliq',
      navigatorKey: navigatorKey, // Global navigatorKey'i kullan
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isLoggedIn
                ? const TabsScreen() // Ana ekranı göster (TabsScreen kullanıyoruz)
                : const LoginScreen(), // Login ekranını göster
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const TabsScreen(),
      },
      initialRoute: '/',
    );
  }
}
