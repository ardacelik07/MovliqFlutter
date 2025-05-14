import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // Import services

import 'height_screen.dart';
import '../providers/user_profile_provider.dart';

class AgeGenderScreen extends ConsumerStatefulWidget {
  const AgeGenderScreen({super.key});

  @override
  ConsumerState<AgeGenderScreen> createState() => _AgeGenderScreenState();
}

class _AgeGenderScreenState extends ConsumerState<AgeGenderScreen> {
  DateTime? selectedDate;
  String? selectedGender;
  String? errorMessage;
  // Removed unused _formKey

  // Helper function to format date as dd/MM/yyyy without intl
  String _formatDate(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    // Enable edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    // Define colors based on the image
    const Color primaryColor = Color(0xFF7BB027); // Green color
    const Color darkGreenColor = Color(0xFF476C17); // Darker shade
    const Color textFieldBgColor =
        Color.fromARGB(195, 0, 0, 0); // Dark background like name_screen
    const Color labelColor =
        Color.fromARGB(255, 222, 222, 222); // Light label color for dark bg
    const Color inputHintColor =
        Color(0xFFBDBDBD); // Hint color like login/register
    const Color inputTextColor = Colors.white; // Text color inside input
    const Color buttonTextColor =
        const Color(0xFF9FD545); // From user's last change

    return Scaffold(
      backgroundColor: primaryColor, // Match scaffold background
      body: Container(
        width: double.infinity, // Ensure container fills width
        height: double.infinity, // Ensure container fills height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 0, 0, 0)
                  .withOpacity(0.9), // Match name_screen gradient
              primaryColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              // Use Column for vertical layout
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 20),
                // Image
                Image.asset(
                  'assets/images/birthday.png', // Keep existing image for now
                  height:
                      MediaQuery.of(context).size.height * 0.4, // Adjust height
                ),
                const Spacer(flex: 2), // Add space before inputs

                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],

                // Birthday Label
                const Text(
                  'Doğum günün ne zaman?',
                  style: TextStyle(color: labelColor, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                // Birthday Input (Calendar Picker)
                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        // Optional: Theme the date picker
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: primaryColor, // header background color
                              onPrimary: Colors.white, // header text color
                              onSurface: Colors.black, // body text color
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    primaryColor, // button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: textFieldBgColor, // Use dark background
                      borderRadius:
                          BorderRadius.circular(12), // Rounded corners
                      // border: Border.all(color: Colors.black), // Removed border
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate != null
                              ? _formatDate(selectedDate!) // Use formatted date
                              : 'Calendar', // Placeholder text
                          style: TextStyle(
                            color: selectedDate != null
                                ? inputTextColor
                                : inputHintColor, // Adjust text color
                            fontSize: 16,
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            color: inputHintColor, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Gender Label
                const Text(
                  'Kendinizi nasıl tanımlarsınız?',
                  style: TextStyle(color: labelColor, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),

// Emoji-based Gender Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ["Erkek", "Kadın", "Diğer"].map((gender) {
                    final bool isSelected = selectedGender == gender;
                    String emoji;

                    switch (gender) {
                      case "Erkek":
                        emoji = "👨";
                        break;
                      case "Kadın":
                        emoji = "👩";
                        break;
                      default:
                        emoji = "👤"; // Mystery face for "Diğer"
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedGender = gender;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF9FD545)
                                : Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emoji,
                                style: TextStyle(
                                  fontSize: 26,
                                  color:
                                      isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                gender,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const Spacer(flex: 3), // Push button to bottom

                // Continue Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(
                        255, 43, 64, 16), // Match name_screen button
                    foregroundColor: buttonTextColor, // White text
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // More rounded
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    // Validate that both fields are selected
                    if (selectedDate != null && selectedGender != null) {
                      setState(() {
                        errorMessage = null; // Clear error if valid
                      });

                      ref.read(userProfileProvider.notifier).updateProfile(
                            birthDate: selectedDate,
                            gender: selectedGender,
                          );

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HeightScreen()),
                      );
                    } else {
                      setState(() {
                        errorMessage =
                            'Lütfen tüm alanları seçin'; // Show error
                      });
                    }
                  },
                  child: const Text('Devam Et'),
                ),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom +
                        20), // Space at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}
