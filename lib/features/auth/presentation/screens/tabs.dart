import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_page.dart';
import 'profile_screen.dart';
import 'store_screen.dart';
import 'record_screen.dart';
import 'leaderboard_screen.dart';
import '../providers/leaderboard_provider.dart';

class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key});

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  DateTime? _lastBackPressTime;

  final List<Widget> _pages = [
    const HomePage(),
    const StoreScreen(),
    const RecordScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    // Leaderboard tab'ine geçiş yapılıyorsa provider'ları temizle
    if (index == 3 && _selectedIndex != 3) {
      // Leaderboard ekranına geçildiğinde verileri yeniden yükle
      // Önce state'i güncelle, sonra Future.microtask ile provider'ları yenile
      setState(() {
        _previousIndex = _selectedIndex;
        _selectedIndex = index;
      });

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

      return; // Aşağıdaki setState'i çalıştırma
    }

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Eğer ana sayfada değilsek, ana sayfaya dön
        if (_selectedIndex != 0) {
          setState(() {
            _previousIndex = _selectedIndex;
            _selectedIndex = 0;
          });
          return false; // Navigasyonu engelleyerek kendi işlemimizi yaptık
        }

        // Ana sayfadaysa direkt uygulamadan çıkış yap
        await SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          child: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: Color(0xFFC4FF62),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
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
