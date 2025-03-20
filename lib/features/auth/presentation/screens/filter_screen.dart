import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen2.dart';
import '../providers/race_settings_provider.dart';
import 'verification_screen.dart';

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  String? _selectedPreference;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                "Koşu Türünü Seç",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tercihini istediğin zaman değiştirebilirsin",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              _buildRunningOptionCard(
                title: "İç Mekan Koşusu",
                description: "Koşu bandında antrenman",
                iconData: Icons.directions_run,
                backgroundImage: "assets/images/indoorfilterbckgrnd.jpg",
                value: "indoor",
              ),
              const SizedBox(height: 16),
              _buildRunningOptionCard(
                title: "Dış Mekan Koşusu",
                description: "Açık havada koşu deneyimi",
                iconData: Icons.terrain,
                backgroundImage: "assets/images/outdoorfilterbckgrnd.jpg",
                value: "outdoor",
              ),
              const Spacer(),
              if (_selectedPreference != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC4FF62),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // Save the selected room type to provider
                        ref
                            .read(raceSettingsProvider.notifier)
                            .setRoomType(_selectedPreference!);

                        // İç mekan seçilirse doğrulama ekranına yönlendir
                        if (_selectedPreference == 'indoor') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VerificationScreen(),
                            ),
                          );
                        } else {
                          // Dış mekan seçilirse direkt süre seçimi ekranına git
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FilterScreen2()),
                          );
                        }
                      },
                      child: const Text(
                        'Devam',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunningOptionCard({
    required String title,
    required String description,
    required IconData iconData,
    required String backgroundImage,
    required String value,
  }) {
    final bool isSelected = _selectedPreference == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPreference = value;
        });
      },
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFFC4FF62), width: 2.5)
              : null,
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Left side - Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4FF62)
                      .withOpacity(isSelected ? 0.4 : 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  color: const Color(0xFFC4FF62),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Middle - Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFC4FF62),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Right side - Arrow
              Icon(
                Icons.arrow_forward,
                color: const Color(0xFFC4FF62),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
