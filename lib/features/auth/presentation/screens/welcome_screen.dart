import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'name_screen.dart';
import 'package:flutter/services.dart'; // Import services

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Enable edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    // Define colors based on the image
    const Color primaryColor = Color(0xFF7BB027); // Green color from the image
    const Color darkGreenColor =
        Color(0xFF476C17); // Darker shade for gradient/button
    const Color textColor = Colors.white;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
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
            child: Column(
              // Use Column for vertical arrangement
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2), // Push content down a bit
                          // Image
                          Image.asset(
                            'assets/images/welcome1.png', // Use the new image
                            height: MediaQuery.of(context).size.height *
                                0.4, // Adjust height based on screen
                          ),
                          const SizedBox(height: 30),
                          // Welcome Text
                          const Text(
                            'Movliq\'e Hoşgeldin', // Updated text
                            style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(flex: 3), // Push button towards bottom
                        ],
                      ),
                    ),
                  ),
                ),
                // Button at the bottom
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                            255, 43, 64, 16), // Darker button background
                        foregroundColor: const Color(0xFF9FD545), // White text
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12), // More rounded corners
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NameScreen(),
                          ),
                        );
                      },
                      child: const Text('Devam Et'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
