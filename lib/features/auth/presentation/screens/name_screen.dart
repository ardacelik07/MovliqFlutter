import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // Import services
import 'package:google_fonts/google_fonts.dart';

import '../providers/user_profile_provider.dart';

import 'age_gender_screen.dart';

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Added isLoading state

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define colors based on the image
    const Color primaryColor = Color(0xFF7BB027); // Green color from the image
    const Color darkGreenColor =
        Color(0xFF476C17); // Darker shade for gradient/button
    const Color textFieldBgColor = Color.fromARGB(195, 0, 0, 0);
    const Color labelColor =
        Color.fromARGB(255, 222, 222, 222); // Dark grey for labels
    const Color inputColor = Color.fromARGB(255, 255, 253, 253);
    const Color buttonTextColor = const Color(0xFF9FD545);

    return Scaffold(
      backgroundColor: primaryColor, // Explicitly set scaffold background
      // Use a gradient background similar to the image
      body: Container(
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
                  SizedBox(
                      height: MediaQuery.of(context).padding.top +
                          20), // Space from top, considering status bar
                  // Image
                  Image.asset(
                    'assets/images/registration.png', // Existing image
                    height: MediaQuery.of(context).size.height *
                        0.35, // Adjust height
                  ),
                  const SizedBox(height: 60),
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: inputColor),
                    decoration: InputDecoration(
                      hintText: 'İsminiz nedir?',
                      hintStyle:
                          GoogleFonts.bangers(color: labelColor, fontSize: 16),
                      filled: true,
                      fillColor: textFieldBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // More rounded
                        borderSide: BorderSide.none, // No border
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'İsminizi giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: inputColor),
                    decoration: InputDecoration(
                      hintText: 'Tercih ettiğiniz kullanıcı adı nedir?',
                      hintStyle:
                          GoogleFonts.bangers(color: labelColor, fontSize: 14),
                      filled: true,
                      fillColor: textFieldBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // More rounded
                        borderSide: BorderSide.none, // No border
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      prefixStyle: const TextStyle(
                          color: labelColor), // Style for prefix
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Kullanıcı adınızı giriniz';
                      }
                      // Basic username validation (no spaces, etc.) - enhance if needed
                      if (value!.contains(' ')) {
                        return 'Kullanıcı adında boşluk olamaz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 60),
                  // Continue Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(
                          255, 43, 64, 16), // Darker button background
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
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              setState(() => _isLoading = true);
                              final String name = _nameController.text.trim();
                              final String username =
                                  _usernameController.text.trim();

                              try {
                                // Step 1: Validate and set username via the new API
                                await ref
                                    .read(userProfileProvider.notifier)
                                    .validateAndSetUsername(username);

                                // Step 2: Update the name locally in the profile model
                                // (validateAndSetUsername already updated the username in _profile object of the notifier)
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updateProfile(name: name);

                                // Step 3: Save the entire profile (name and validated username)
                                // using the general /User/update-profile endpoint.
                                await ref
                                    .read(userProfileProvider.notifier)
                                    .saveProfile();

                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AgeGenderScreen(),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(e
                                            .toString()
                                            .replaceFirst("Exception: ", ""))),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            }
                          },
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('Devam Et', style: GoogleFonts.bangers()),
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
}
