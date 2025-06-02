import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // Commented out
import '../widgets/font_widget.dart'; // Added FontWidget import

import 'finish_screen.dart';
import '../providers/user_profile_provider.dart';

class ActiveScreen extends ConsumerStatefulWidget {
  const ActiveScreen({super.key});

  @override
  ConsumerState<ActiveScreen> createState() => _ActiveScreenState();
}

class _ActiveScreenState extends ConsumerState<ActiveScreen> {
  String? _selectedLevel;

  // Define the primary green color for the gradient
  static const Color primaryGreen = Color(0xFF7BB027);

  @override
  Widget build(BuildContext context) {
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
              primaryGreen, // Start with the app's green
              // End with black
            ],
            begin: Alignment.topCenter, // Gradient from top
            end: Alignment.bottomCenter, // to bottom
            stops: [0.0, 0.8], // Control the blend point (adjust as needed)
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/activity.png',
                  height: 250,
                ),
                const SizedBox(height: 20),
                FontWidget(
                  text: "Ne kadar aktif spor yapıyorsunuz?",
                  styleType: TextStyleType.titleMedium, // Adjusted for Bangers
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  // Change text color to white to be visible on the dark gradient
                  color: Colors.white,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Pass the context to update text colors in options
                _buildActivityOption(
                  context,
                  'Yeni Başlayan',
                  'Yeni adımlar atmaya hazırım,harekete geçmek istiyorum',
                  Icons.directions_walk,
                  'beginner',
                ),
                const SizedBox(height: 16),
                _buildActivityOption(
                  context,
                  'Orta Seviye',
                  'Zaman zaman spor yapıyorum, daha istikrarlı olmak istiyorum',
                  Icons.favorite,
                  'intermediate',
                ),
                const SizedBox(height: 16),
                _buildActivityOption(
                  context,
                  'İleri Seviye',
                  'Spor hayatımın bir parçası, her gün kendimi zorlamaya hazırım',
                  Icons.fitness_center,
                  'advanced',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF476C17),
                    foregroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _selectedLevel != null
                      ? () {
                          ref.read(userProfileProvider.notifier).updateProfile(
                                activityLevel: _selectedLevel,
                              );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FinishScreen()),
                          );
                        }
                      : null,
                  child: FontWidget(
                      text: 'Devam Et',
                      styleType: TextStyleType.labelLarge,
                      color: primaryGreen,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityOption(
    // Add BuildContext to access theme/colors if needed later
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedLevel == value;
    // Determine text colors based on the background gradient
    final Color titleColor = isSelected ? Colors.black : Colors.white;
    final Color subtitleColor = isSelected ? Colors.black54 : Colors.white70;
    final Color iconColor = isSelected ? Colors.black : Colors.white;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLevel = value;
        });
      },
      borderRadius: BorderRadius.circular(12), // Ensure ripple matches border
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Keep selected color, make unselected slightly transparent white
          color: isSelected
              ? const Color(0xFFC4FF62)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          // Remove border, selection is clear from background color
          // border: Border.all(
          //   color: isSelected ? Colors.black : Colors.grey.shade300,
          //   width: isSelected ? 2 : 1,
          // ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor, // Use dynamically determined icon color
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FontWidget(
                    text: title,
                    styleType: TextStyleType.labelLarge, // Adjusted for Bangers
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor, // Use dynamic title color
                  ),
                  FontWidget(
                    text: subtitle,
                    styleType:
                        TextStyleType.labelMedium, // Adjusted for Bangers
                    fontSize: 14,
                    color: subtitleColor, // Use dynamic subtitle color
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                // Make checkmark black for visibility on light selected background
                color: Colors.black,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
