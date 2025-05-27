import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // Import services

import 'weight_screen.dart';
import '../providers/user_profile_provider.dart';

class HeightScreen extends ConsumerStatefulWidget {
  const HeightScreen({super.key});

  @override
  ConsumerState<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends ConsumerState<HeightScreen> {
  // Removed ft and in controllers, keep only cm
  // final TextEditingController _ftController = TextEditingController();
  // final TextEditingController _inController = TextEditingController();
  final TextEditingController _cmController =
      TextEditingController(); // Controller for cm input
  // bool _isFtIn = true; // Removed ft/in toggle state
  final _formKey = GlobalKey<FormState>();

  // Define colors at class level
  static const Color primaryColor = Color(0xFF7BB027);

  static const Color labelColor =
      Color.fromARGB(255, 222, 222, 222); // Light label color

  static const Color unitLabelColor =
      Color.fromARGB(255, 222, 222, 222); // Light color for ft/in/cm labels

  static const Color buttonTextColor = Color(0xFF9FD545);

  @override
  void dispose() {
    // Dispose only the cm controller
    // _ftController.dispose();
    // _inController.dispose();
    _cmController.dispose();
    super.dispose();
  }

  // Removed _onUnitChanged function
  // void _onUnitChanged(bool isSelectedFtIn) { ... }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 0, 0, 0).withOpacity(0.9),
              primaryColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 20),
                  // Image
                  Image.asset(
                    'assets/images/uzunluk.png',
                    height: MediaQuery.of(context).size.height * 0.4,
                  ),
                  const SizedBox(height: 30),

                  // Title
                  const Text(
                    "Boyunuz nedir?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Input Fields Section - Only CM input now
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120, // Width for cm input
                        child: TextFormField(
                          controller: _cmController, // Use cm controller
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 255, 255)),
                          decoration: _inputDecoration(),
                          validator: (value) {
                            if (value?.isEmpty ?? true)
                              return ''; // Use form level validation
                            // Optional: Add reasonable height validation (e.g., > 50 cm)
                            final cm = int.tryParse(value!);
                            if (cm == null || cm <= 50 || cm > 250) return '';
                            return null;
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text('cm',
                            style:
                                TextStyle(color: unitLabelColor, fontSize: 16)),
                      ),
                    ],
                  ),

                  // Removed Unit Selection Chips Row
                  // const SizedBox(height: 24),
                  // Row( ... chips ... ),

                  const SizedBox(height: 40), // Adjusted spacing

                  // Continue Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 43, 64, 16),
                      foregroundColor: buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        double heightInCm = 0;
                        bool isValid = true;

                        try {
                          // Only handle CM input now
                          if (_cmController.text.isEmpty) {
                            isValid = false;
                          } else {
                            heightInCm = double.parse(_cmController.text);
                          }

                          if (heightInCm <= 50 || heightInCm > 250)
                            isValid =
                                false; // Height must be positive and reasonable

                          if (!isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Lütfen geçerli bir boy (50-250 cm) girin')),
                            );
                            return; // Stop processing if invalid
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Geçersiz sayı formatı')),
                          );
                          return; // Stop if parsing fails
                        }

                        ref.read(userProfileProvider.notifier).updateProfile(
                              height: heightInCm,
                            );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const WeightScreen()),
                        );
                      } else {
                        // Show general validation error if form validation fails
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Lütfen boyunuzu (cm) girin')),
                        );
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
      ),
    );
  }

  // Helper for consistent input decoration
  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color.fromARGB(195, 0, 0, 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 12), // Adjust padding
      isDense: true, // Make field compact
      // Remove labelText, use separate Text widgets for ft/in/cm
      // Remove hintText as value should always be present or validated
      errorStyle: const TextStyle(height: 0), // Hide default error text space
      errorBorder: OutlineInputBorder(
        // Add red border on error
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}
