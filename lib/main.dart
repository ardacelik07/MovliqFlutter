import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/tabs.dart'; // HomePage yerine TabsScreen kullanacağız
import 'core/services/storage_service.dart';

void main() {
  WidgetsFlutterBinding
      .ensureInitialized(); // Asenkron işlemleri başlatmak için
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

  Future<void> _checkLoginStatus() async {
    final bool hasToken = await StorageService.hasToken();
    setState(() {
      _isLoggedIn = hasToken;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movliq',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLoggedIn
              ? const TabsScreen() // Ana ekranı göster (TabsScreen kullanıyoruz)
              : const LoginScreen(), // Login ekranını göster
    );
  }
}
