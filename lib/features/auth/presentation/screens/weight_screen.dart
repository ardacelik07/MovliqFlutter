import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // Import services
// import 'package:google_fonts/google_fonts.dart'; // Commented out
import '../widgets/font_widget.dart'; // Added FontWidget import
import 'active_screen.dart';
import '../providers/user_profile_provider.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  final TextEditingController _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Define colors (similar to HeightScreen)
  static const Color primaryColor = Color(0xFF7BB027);
  static const Color labelColor = Color.fromARGB(255, 222, 222, 222);
  static const Color unitLabelColor = Color.fromARGB(255, 222, 222, 222);
  static const Color buttonTextColor = Color(0xFF9FD545);

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

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
                    'assets/images/agirlik.png', // Assuming this is the correct image
                    height: MediaQuery.of(context).size.height * 0.4,
                  ),
                  const SizedBox(height: 30),

                  // Title
                  FontWidget(
                    text: "Kilonuz nedir?",
                    styleType:
                        TextStyleType.titleMedium, // Adjusted for Bangers
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Input Field and Unit Label Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120, // Adjust width as needed
                        child: TextFormField(
                          controller: _weightController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(
                              // Keep direct TextStyle for TextFormField
                              fontFamily:
                                  'Bangers', // Explicitly use Bangers if needed here
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 255, 255)),
                          decoration: _inputDecoration().copyWith(
                            suffixText: 'kg',
                            suffixStyle: TextStyle(
                              // Keep direct TextStyle for suffixStyle
                              fontFamily:
                                  'Bangers', // Explicitly use Bangers if needed here
                              color: unitLabelColor,
                              fontSize: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return '';
                            final weight = double.tryParse(value!);
                            if (weight == null || weight <= 0) return '';
                            // Add reasonable weight limits if needed
                            // if (weight < 20 || weight > 250) return ''; // kg limits
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
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
                        double weightInKg = 0;
                        bool isValid = true;

                        try {
                          final weight = double.parse(_weightController.text);
                          if (weight <= 0) isValid = false;

                          // Only process kg now
                          // Add reasonable kg limits if desired
                          // if (weight < 20 || weight > 250) isValid = false;
                          if (isValid) weightInKg = weight;

                          if (!isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Lütfen geçerli bir ağırlık (kg) girin')),
                            );
                            return;
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Geçersiz sayı formatı')),
                          );
                          return;
                        }

                        ref.read(userProfileProvider.notifier).updateProfile(
                              weight: weightInKg,
                            );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ActiveScreen()),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Lütfen ağırlığınızı (kg) girin')),
                        );
                      }
                    },
                    child: FontWidget(
                        text: 'Devam Et',
                        styleType: TextStyleType.labelLarge,
                        color: buttonTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for consistent input decoration (same as HeightScreen)
  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color.fromARGB(195, 0, 0, 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      isDense: true,
      errorStyle: const TextStyle(height: 0),
      errorBorder: OutlineInputBorder(
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
