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
    // Ensure tab is set to 0 (Home) when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force reset to home tab whenever TabsScreen is initialized
      ref.read(selectedTabProvider.notifier).state = 0;
      print('💡 TabsScreen: Tab index explicitly set to 0 (Home)');
    });
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

        // Token is valid, now fetch user data BEFORE marking loading as complete
        await ref.read(userDataProvider.notifier).fetchUserData();

        // Set loading to false only after token check AND initial data fetch
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
        extendBody: true, // Draw body behind notch
        // Use IndexedStack to keep all pages in the tree but show only one
        body: IndexedStack(
          index: selectedIndex,
          children: _pages,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _onItemTapped(2), // Index 2 for Record
          backgroundColor: const Color(0xFFC4FF62), // Lime green
          shape: const CircleBorder(), // Ensure it's always circular
          child: const Icon(Icons.fiber_manual_record,
              color: Colors.black), // Use appropriate icon
          elevation: 2.0,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // Wrap BottomAppBar with SizedBox to control height
        bottomNavigationBar: SizedBox(
          height: 52.0, // Set desired height (adjust as needed)
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            color: const Color.fromARGB(255, 30, 30, 30), // Dark background
            padding: const EdgeInsets.symmetric(
                horizontal: 0), // Remove default padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildNavItem(
                    Icons.home_outlined, Icons.home, 'Home', 0, selectedIndex),
                _buildNavItem(Icons.store_outlined, Icons.store, 'Store', 1,
                    selectedIndex),
                const SizedBox(width: 40), // Placeholder for the notch
                _buildNavItem(Icons.leaderboard_outlined, Icons.leaderboard,
                    'Leaderboard', 3, selectedIndex),
                _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 4,
                    selectedIndex),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build navigation items for BottomAppBar
  // This directly uses selectedIndex to determine the color, maintaining original logic
  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label,
      int index, int selectedIndex) {
    final bool isSelected = selectedIndex == index;
    // Use the exact colors from the original BottomNavigationBar
    final Color color = isSelected ? const Color(0xFFC4FF62) : Colors.grey;

    return InkWell(
      onTap: () => _onItemTapped(index),
      customBorder:
          const CircleBorder(), // Make tap area circular for better feel
      child: Padding(
        // Reduce vertical padding slightly
        padding: const EdgeInsets.symmetric(
            vertical: 4.0, horizontal: 12.0), // Reduced from 6.0
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: color,
              // Reduce icon size slightly
              size: 22, // Reduced from 24
            ),
            const SizedBox(height: 3), // Reduced from 4
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10, // Keeping font size the same for now
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
