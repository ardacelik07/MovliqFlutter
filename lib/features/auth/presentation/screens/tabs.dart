import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'home_page.dart';
import 'profile_screen.dart';
import 'store_screen.dart';
import 'record_screen.dart';
import 'leaderboard_screen.dart';
import '../providers/leaderboard_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../screens/login_screen.dart';
import '../providers/user_data_provider.dart';

// Provider for the selected tab index
final selectedTabProvider = StateProvider<int>((ref) => 0);

class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key});

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  DateTime? _lastBackPressTime;
  bool _isLoading = true; // Token kontrolü için yükleme durumu

  final List<Widget> _pages = [
    const HomePage(),
    const StoreScreen(),
    const RecordScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkToken(); // Token geçerliliğini kontrol et
  }

  // Token kontrolü
  Future<void> _checkToken() async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        print('⚠️ Tabs: Token bulunamadı, login ekranına yönlendiriliyor');
        _redirectToLogin();
        return;
      }

      try {
        // Token formatını kontrol et
        final tokenData = jsonDecode(tokenJson);

        if (!tokenData.containsKey('token') ||
            tokenData['token'] == null ||
            tokenData['token'].isEmpty) {
          print('⚠️ Tabs: Token format hatası, login ekranına yönlendiriliyor');
          _redirectToLogin();
          return;
        }

        // Token geçerli, yükleme tamamlandı
        setState(() {
          _isLoading = false;
        });
        // Fetch user data once token is confirmed
        ref.read(userDataProvider.notifier).fetchUserData();
      } catch (e) {
        print('⚠️ Tabs: Token parse hatası: $e');
        _redirectToLogin();
      }
    } catch (e) {
      print('⚠️ Tabs: Token kontrolü sırasında hata: $e');
      _redirectToLogin();
    }
  }

  // Login ekranına yönlendir
  void _redirectToLogin() async {
    await StorageService.deleteToken();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    final currentIndex = ref.read(selectedTabProvider);

    // Leaderboard tab'ine geçiş yapılıyorsa provider'ları temizle
    if (index == 3 && currentIndex != 3) {
      // Leaderboard ekranına geçildiğinde verileri yeniden yükle
      // Update the provider state first
      ref.read(selectedTabProvider.notifier).state = index;

      // Microtask ile widget ağacının güncellenmesinden sonra çalıştır
      Future.microtask(() {
        try {
          final isOutdoor = ref.read(isOutdoorSelectedProvider);
          if (isOutdoor) {
            ref.refresh(outdoorLeaderboardProvider);
          } else {
            ref.refresh(indoorLeaderboardProvider);
          }
        } catch (e) {
          debugPrint("Hata: $e");
        }
      });

      return; // Don't run the code below
    }

    // Update the provider state for other tabs
    ref.read(selectedTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    // Read the current index from the provider
    final selectedIndex = ref.watch(selectedTabProvider);

    // Token kontrol yüklemesi sırasında bekletme
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Use the provider's value to check if on home page
        if (ref.read(selectedTabProvider) != 0) {
          // Navigate to home by updating the provider
          ref.read(selectedTabProvider.notifier).state = 0;
          return false; // Prevent default back navigation
        }

        // Ana sayfadaysa direkt uygulamadan çıkış yap
        await SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        body: _pages[selectedIndex],
        bottomNavigationBar: Container(
          child: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: Color(0xFFC4FF62),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store_outlined),
                activeIcon: Icon(Icons.store),
                label: 'Store',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fiber_manual_record_outlined),
                activeIcon: Icon(Icons.fiber_manual_record),
                label: 'Record',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                activeIcon: Icon(Icons.leaderboard),
                label: 'Leaderboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
