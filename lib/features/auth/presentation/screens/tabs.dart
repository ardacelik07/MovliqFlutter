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
import '../../../../core/services/http_interceptor.dart';
import '../screens/login_screen.dart';

// Provider for managing the selected tab index
final selectedTabProvider = StateProvider<int>((ref) => 0);

class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key});

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  // Remove local state for selected index
  // int _selectedIndex = 0;
  int _previousIndex = 0; // Keep for leaderboard logic if needed
  DateTime? _lastBackPressTime;
  bool _isLoading = true;

  final List<Widget> _pages = [
    const HomePage(),
    const StoreScreen(), // Index 1
    const RecordScreen(),
    const LeaderboardScreen(), // Index 3
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    try {
      final tokenJson = await StorageService.getToken();

      if (tokenJson == null) {
        print('⚠️ Tabs: Token bulunamadı, login ekranına yönlendiriliyor');
        _redirectToLogin();
        return;
      }

      try {
        final tokenData = jsonDecode(tokenJson);

        if (!tokenData.containsKey('token') ||
            tokenData['token'] == null ||
            tokenData['token'].isEmpty) {
          print('⚠️ Tabs: Token format hatası, login ekranına yönlendiriliyor');
          _redirectToLogin();
          return;
        }

        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        print('⚠️ Tabs: Token parse hatası: $e');
        _redirectToLogin();
      }
    } catch (e) {
      print('⚠️ Tabs: Token kontrolü sırasında hata: $e');
      _redirectToLogin();
    }
  }

  void _redirectToLogin() async {
    await StorageService.deleteToken();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Update the provider when a tab is tapped
  void _onItemTapped(int index) {
    final currentIndex = ref.read(selectedTabProvider);
    // Update previous index *before* changing the state
    _previousIndex = currentIndex;

    // Leaderboard specific logic
    if (index == 3 && currentIndex != 3) {
      // Update provider first
      ref.read(selectedTabProvider.notifier).state = index;

      // Then refresh leaderboard data
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
      return;
    }

    // Update the provider for other tabs
    ref.read(selectedTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    // Read the selected index from the provider
    final selectedIndex = ref.watch(selectedTabProvider);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Use the provider's value for logic
        if (selectedIndex != 0) {
          // Update provider to go to home
          _previousIndex = selectedIndex;
          ref.read(selectedTabProvider.notifier).state = 0;
          return false;
        }
        await SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        // Use index from provider
        body: _pages[selectedIndex],
        bottomNavigationBar: Container(
          child: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: Color(0xFFC4FF62),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            // Use index from provider
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
