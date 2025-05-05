import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/tabs.dart'; // HomePage yerine TabsScreen kullanacağız
import 'core/services/storage_service.dart';
import 'core/services/http_interceptor.dart';
import 'dart:convert';
import 'features/auth/presentation/providers/user_data_provider.dart'; // Import userDataProvider
import 'features/auth/presentation/providers/race_provider.dart'; // RaceNotifier Provider import
import 'features/auth/presentation/screens/race_screen.dart'; // RaceScreen import
import 'core/theme/app_theme.dart'; // AppTheme import (varsayılan tema için)
import 'features/auth/presentation/screens/welcome_screen.dart'; // WelcomeScreen import
import 'features/auth/presentation/screens/finish_race_screen.dart'; // FinishRaceScreen import
import 'package:intl/date_symbol_data_local.dart'; // Import for locale initialization

// Global navigator anahtarı
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure bindings are initialized

  // Initialize date formatting for Turkish locale
  await initializeDateFormatting('tr_TR', null);

  // HttpInterceptor'a NavigatorKey'i daha sonra atayacağız
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() =>
      _MyAppState();
}

// WidgetsBindingObserver ekliyoruz
class _MyAppState extends ConsumerState<MyApp>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    // Observer'ı ekle
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Observer'ı kaldır
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana geldiğinde kontrol et (küçük gecikmeyle)
      Future.delayed(
          const Duration(milliseconds: 100),
          _checkActiveRaceAndNavigate);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Uygulama başladıktan ve route'lar hazır olduktan sonra navigatorKey mevcut olacak
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        HttpInterceptor.setNavigator(
            navigatorKey.currentState!);
      }
    });
  }

  void _checkActiveRaceAndNavigate() {
    // Navigator ve context'in hazır olduğundan emin ol
    final navigator = navigatorKey.currentState;
    final currentContext =
        navigatorKey.currentContext;
    if (navigator == null ||
        currentContext == null) {
      debugPrint(
          '[AppLifecycle] Navigator or context not ready yet.');
      return;
    }

    // Provider container'ını al
    try {
      final container = ProviderScope.containerOf(
          currentContext);
      final raceState =
          container.read(raceNotifierProvider);

      if (raceState.isRaceActive ||
          raceState.isPreRaceCountdownActive) {
        debugPrint(
            '[AppLifecycle] Aktif yarış tespit edildi. Oda: ${raceState.roomId}');

        // Mevcut route'u kontrol et
        String? currentRouteName;
        navigator.popUntil((route) {
          currentRouteName = route.settings.name;
          return true; // Sadece ismi al
        });

        final bool isOnRaceScreen =
            currentRouteName == '/race';

        if (!isOnRaceScreen) {
          debugPrint(
              '[AppLifecycle] Kullanıcı RaceScreende değil, yönlendiriliyor...');
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              settings: const RouteSettings(
                  name:
                      '/race'), // Route'a isim ver
              builder: (context) => RaceScreen(
                // Sadece gerekli başlangıç parametreleri
                roomId: raceState.roomId!,
                // myUsername artık RaceScreen içinde kullanılmıyor gibi
                // myUsername: raceState.userEmail?.split('@')[0],
              ),
            ),
            (route) => false,
          );
        } else {
          debugPrint(
              '[AppLifecycle] Kullanıcı zaten RaceScreende.');
        }
      } else if (raceState.isRaceFinished) {
        debugPrint(
            '[AppLifecycle] Bitmiş yarış tespit edildi. Oda: ${raceState.roomId}');
        // Check current route
        String? currentRouteName;
        navigator.popUntil((route) {
          currentRouteName = route.settings.name;
          return true; // Just get the name
        });

        final bool isOnFinishScreen =
            currentRouteName == '/finish';

        if (!isOnFinishScreen) {
          debugPrint(
              '[AppLifecycle] Kullanıcı FinishScreende değil, yönlendiriliyor...');
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              settings: const RouteSettings(
                  name:
                      '/finish'), // <-- Set route name
              builder: (context) =>
                  FinishRaceScreen(
                // Get data from the finished state
                leaderboard:
                    raceState.leaderboard,
                myEmail: raceState.userEmail,
                isIndoorRace:
                    raceState.isIndoorRace,
                profilePictureCache:
                    raceState.profilePictureCache,
              ),
            ),
            (route) => false,
          );
        } else {
          debugPrint(
              '[AppLifecycle] Kullanıcı zaten FinishScreende.');
        }
      } else {
        debugPrint(
            '[AppLifecycle] Aktif veya bitmiş yarış yok.');
      }
    } catch (e) {
      debugPrint(
          '[AppLifecycle] Provider container alınırken hata: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final bool hasToken =
          await StorageService.hasToken();

      if (hasToken) {
        final tokenJson =
            await StorageService.getToken();
        if (tokenJson == null) {
          await StorageService.deleteToken();
          if (!mounted) return;
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
          return;
        }

        try {
          final tokenData = jsonDecode(tokenJson);
          if (!tokenData.containsKey('token') ||
              tokenData['token'] == null ||
              tokenData['token'].isEmpty) {
            await StorageService.deleteToken();
            if (!mounted) return;
            setState(() {
              _isLoggedIn = false;
              _isLoading = false;
            });
            return;
          }
          if (!mounted) return;
          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });
          ref
              .read(userDataProvider.notifier)
              .fetchUserData();
          ref
              .read(userDataProvider.notifier)
              .fetchCoins();
          return;
        } catch (e) {
          print('Token parse hatası: $e');
          await StorageService.deleteToken();
          if (!mounted) return;
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
          return;
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print(
          'Login durumu kontrol edilirken hata: $e');
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Movliq',
      navigatorKey:
          navigatorKey, // Global navigatorKey'i kullan
      theme: ThemeData(
        // Orijinal tema yapısı
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute:
          '/', // initialRoute tanımlıyoruz
      routes: {
        '/': (context) => _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator())
            : _isLoggedIn
                ? const TabsScreen() // Giriş yapılmışsa TabsScreen
                : const LoginScreen(), // Giriş yapılmamışsa LoginScreen (orijinaldeki gibi)
        '/login': (context) =>
            const LoginScreen(),
        '/home': (context) => const TabsScreen(),
        // RaceScreen için route tanımı ekliyoruz
        '/race': (context) => RaceScreen(
              // Route'un var olması için geçici değerler
              roomId: 0,
              // profilePictureCache: const {}, // Removed
            ),
        // Add FinishRaceScreen route
        '/finish': (context) =>
            const FinishRaceScreen(
              // Placeholder data for route definition
              leaderboard: [],
              isIndoorRace: false,
              profilePictureCache: {},
            ),
        // Diğer route tanımlarınız...
      },
    );
  }
}
