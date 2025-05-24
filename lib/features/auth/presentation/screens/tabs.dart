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
import '../providers/recording_state_provider.dart';

// Provider for managing the selected tab index
final selectedTabProvider = StateProvider<int>((ref) => 0);

class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key});

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  int _previousIndex = 0; // Keep for leaderboard logic if needed
  DateTime? _lastBackPressTime;
  bool _isLoading = true;

  final List<Widget> _pages = [
    const HomePage(),
    StoreScreen(),
    const RecordScreen(),
    const LeaderboardScreen(),
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
        if (tokenJson == null || tokenJson.isEmpty) {
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

  // Confirmation Dialog
  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible:
              false, // Kullanıcının dışarı tıklayarak kapatmasını engelle
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E), // Koyu arkaplan
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              contentPadding: const EdgeInsets.all(24.0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFAEF45F), // Yeşil ikon arkaplanı
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 28.0,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  const Text(
                    'Emin misiniz?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  const Text(
                    'Kayıt modunu sonlandırmadan çıktığında kaydedilmeyen veriler kaybolacaktır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70, // Daha açık gri tonu
                      fontSize: 14.0,
                    ),
                  ),
                  const SizedBox(height: 28.0),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFAEF45F), // Vazgeç buton rengi
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'Vazgeç',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(false); // Onaylamadı
                          },
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF3A3A3C), // Çık buton rengi
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'Çık',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(true); // Onayladı
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // actions: artık Row içinde content'e dahil edildi.
            );
          },
        ) ??
        false;
  }

  void _onItemTapped(int index) async {
    final currentTabIndex = ref.read(selectedTabProvider);
    final bool isRecordingActive = ref.read(recordStateProvider);

    // Original logic for handling tab changes when recording is active
    if (currentTabIndex == 2 && index != 2 && isRecordingActive) {
      final confirm = await _showConfirmationDialog();
      if (!confirm) {
        return;
      }
      ref.read(recordStateProvider.notifier).cancelRecording();
    }

    // Original logic for preventing navigation to RecordScreen if already recording and on that tab
    if (index == 2 && currentTabIndex == 2 && isRecordingActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivite kaydı devam ediyor.')),
        );
      }
      return;
    }

    // Original logic to prevent re-selecting the same tab
    // (unless it's index 2 and not recording, or a different scenario where re-selection is allowed)
    if (currentTabIndex == index && !(index == 2 && !isRecordingActive)) {
      // Adjusted condition
      if (currentTabIndex == index)
        return; // Simplified: if same tab, do nothing
    }

    _previousIndex = currentTabIndex;
    ref.read(selectedTabProvider.notifier).state = index;

    if (index == 3) {
      // Leaderboard tab
      Future.microtask(() {
        try {
          final isOutdoor = ref.read(isOutdoorSelectedProvider);
          if (isOutdoor) {
            ref.refresh(outdoorLeaderboardProvider);
          } else {
            ref.refresh(indoorLeaderboardProvider);
          }
        } catch (e) {
          if (kDebugMode) {
            print("Leaderboard refresh error: $e");
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabProvider);
    const Color unselectedColor =
        Color(0xFF8E8E93); // Greyish color for unselected icons
    const Color selectedBgColor = Color(0xFFC4FF62); // Highlight green
    const Color navBarColor =
        Color.fromARGB(255, 0, 0, 0); // Dark blue/purple from image

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black, // Consistent background
        body: Center(
          child: CircularProgressIndicator(color: selectedBgColor),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final selectedIndex = ref.watch(selectedTabProvider);
        final bool isRecordingActive = ref.read(recordStateProvider);

        if (selectedIndex == 2 && isRecordingActive) {
          final confirm = await _showConfirmationDialog();
          if (!confirm) {
            return false;
          }
          ref.read(recordStateProvider.notifier).cancelRecording();
          ref.read(selectedTabProvider.notifier).state = 0;
          _previousIndex = selectedIndex;
          return false;
        }

        if (selectedIndex != 0) {
          _previousIndex = selectedIndex;
          ref.read(selectedTabProvider.notifier).state = 0;
          return false;
        }
        await SystemNavigator.pop();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Match background
        extendBody: true, // Allows body to go behind the notched bar
        body: _pages[selectedIndex],
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Container(
          // Gradient Circle FAB
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 195, 255, 98),
                  selectedBgColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: selectedBgColor.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _onItemTapped(2), // Index 2 for RecordScreen
              child: const Icon(
                Icons.hourglass_bottom,
                color: Colors.black, // Black color for contrast
                size: 28, // Adjust size as needed
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: navBarColor,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0, // Space around the FAB
          height: 65.0, // Standard height
          padding: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _buildNavItem(
                  // Home
                  index: 0,
                  selectedIndex: selectedIndex,
                  iconData: Icons.home_outlined,
                  activeColor: selectedBgColor,
                  inactiveColor: unselectedColor),
              _buildNavItem(
                  // Store
                  index: 1,
                  selectedIndex: selectedIndex,
                  iconData: Icons.store_outlined,
                  activeColor: selectedBgColor,
                  inactiveColor: unselectedColor),
              const SizedBox(width: 48), // Spacer for FAB notch
              _buildNavItem(
                  // Leaderboard
                  index: 3,
                  selectedIndex: selectedIndex,
                  iconData: Icons.leaderboard_outlined,
                  activeColor: selectedBgColor,
                  inactiveColor: unselectedColor),
              _buildNavItem(
                  // Profile
                  index: 4,
                  selectedIndex: selectedIndex,
                  iconData: Icons.person_outline,
                  activeColor: selectedBgColor,
                  inactiveColor: unselectedColor),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build navigation items
  Widget _buildNavItem({
    required int index,
    required int selectedIndex,
    required IconData iconData,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    const Color navBarColor = Color(0xFF1A1F36); // Define color here
    final bool isSelected = index == selectedIndex;
    // Icon color is now simply active or inactive color
    final Color iconColor = isSelected ? activeColor : inactiveColor;

    // Removed special gradient background logic for index 0
    final Widget iconWidget = Icon(iconData, color: iconColor, size: 28);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          customBorder: const CircleBorder(), // Make tap area circular
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10.0), // Vertical padding for tap area
            alignment: Alignment.center,
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}
