import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/tabs.dart';
import '../../../onboarding/presentation/screens/guiding_main_screen.dart';

import '../providers/user_profile_provider.dart';
import '../providers/user_data_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class FinishScreen extends ConsumerStatefulWidget {
  const FinishScreen({super.key});

  @override
  ConsumerState<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends ConsumerState<FinishScreen> {
  String? _selectedPreference;
  bool _isLoading = false;

  // Define the primary green color for the gradient
  static const Color primaryGreen = Color(0xFF7BB027);
  // Define colors based on the image and consistent themes
  static const Color titleColor = Colors.white;
  static const Color optionSelectedBgColor = Color(0xFFC4FF62);
  static const Color optionUnselectedBgColor =
      Color.fromARGB(60, 255, 255, 255);
  static const Color optionIconColor = Colors.white;
  static const Color optionTitleColor = Colors.white;
  static const Color optionSelectedIconColor = Colors.black;
  static const Color optionSelectedTitleColor = Colors.black;
  static const Color buttonBgColor = Color(0xFF476C17);
  static const Color buttonTextColor = Color(0xFF9FD545);

  @override
  Widget build(BuildContext context) {
    // Provider'ı dinle
    ref.listen(userProfileProvider, (previous, next) {
      next.whenOrNull(
        loading: () {
          setState(() => _isLoading = true);
        },
        error: (error, stack) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.toString()}')),
            );
          }
        },
        data: (_) async {
          setState(() => _isLoading = false);
          // Fetch user data and reset tab before navigating
          await ref.read(userDataProvider.notifier).fetchUserData();
          if (!mounted) return;
          ref.read(selectedTabProvider.notifier).state = 0;
          // TabsScreen yerine GuidingMainScreen'e yönlendir
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const GuidingMainScreen(),
            ),
          );
        },
      );
    });

    return Scaffold(
      // Remove the explicit white background color
      // backgroundColor: Colors.white,
      body: Container(
        // Add Container to apply the gradient
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              primaryGreen, // End with black
            ],
            begin: Alignment.topCenter, // Gradient from top
            end: Alignment.bottomCenter, // to bottom
            stops: [0.0, 0.8], // Control the blend point
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/images/finish1.png',
                  height: 300,
                ),
                const SizedBox(height: 60),
                Text(
                  "Nerede koşmayı tercih edersin?",
                  style: GoogleFonts.bangers(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor, // Change text color to white
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildPreferenceOption(
                        'Dış Mekan',
                        Icons.landscape_outlined,
                        'outdoors',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPreferenceOption(
                        'İç Mekan',
                        Icons.fitness_center_outlined,
                        'gym',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        buttonBgColor, // Use defined button background color
                    foregroundColor:
                        buttonTextColor, // Use defined button text color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isLoading || _selectedPreference == null
                      ? null
                      : _handleComplete,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Tamamla', style: GoogleFonts.bangers()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceOption(
    String title,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedPreference == value;
    // Determine colors based on selection and background
    final Color bgColor = isSelected
        ? optionSelectedBgColor
        : optionUnselectedBgColor; // Semi-transparent white
    final Color iconColor =
        isSelected ? optionSelectedIconColor : optionIconColor;
    final Color titleColor =
        isSelected ? optionSelectedTitleColor : optionTitleColor;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPreference = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor, // Use dynamic background color
          borderRadius: BorderRadius.circular(12),
          // Remove border, rely on background color
          // border: Border.all(
          //   color: isSelected ? Color(0xFFC4FF62) : Colors.grey.shade300,
          //   width: isSelected ? 2 : 1,
          // ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor, // Use dynamic icon color
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.bangers(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: titleColor, // Use dynamic title color
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleComplete() async {
    try {
      // Önce mevcut state'i kontrol et
      final currentProfile = ref.read(userProfileProvider).value;
      if (currentProfile == null) {
        throw Exception('Profile data is missing');
      }

      // Eksik zorunlu alanları kontrol et
      if (currentProfile.name.isEmpty ||
          currentProfile.username.isEmpty ||
          currentProfile.gender.isEmpty ||
          currentProfile.height <= 0 ||
          currentProfile.weight <= 0 ||
          currentProfile.activityLevel.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lütfen tüm zorunlu alanları doldurun.')),
        );
        // Hata durumunda işlemi durdur
        return;
      }

      // Son tercihi güncelle
      ref.read(userProfileProvider.notifier).updateProfile(
            runningPreference: _selectedPreference,
          );

      // Profili kaydet
      // Bu işlem ref.listen içinde zaten navigasyonu tetikleyecek.
      // Bu yüzden buradaki await'ten sonra ayrıca navigasyon yapmaya gerek yok.
      await ref.read(userProfileProvider.notifier).saveProfile();

      // Kullanıcı verilerini yenileme ve navigasyon ref.listen içinde yapılacak.
      // await ref.read(userDataProvider.notifier).fetchUserData();
      // ref.listen zaten başarılı saveProfile sonrası fetchUserData çağırıyor,
      // bu satır _handleComplete akışında navigasyon öncesi garantiliyor.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
