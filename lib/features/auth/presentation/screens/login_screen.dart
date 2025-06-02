import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/background_widget.dart';
import '../widgets/social_login_button.dart';
import '../widgets/tagline_widget.dart';
import '../widgets/footer_widget.dart';
import '../screens/register_screen.dart';
import '../screens/login_input_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/font_widget.dart';
import '../widgets/privacy_policy_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeUser());
  }

  Future<void> _checkFirstTimeUser() async {
    // TODO: Implement actual first-time user check (e.g., using shared_preferences)
    // For now, we'll simulate it as true
    bool isFirstTime = await _getIsFirstTime();

    if (isFirstTime && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // User must interact with the dialog
        builder: (BuildContext dialogContext) {
          return PrivacyPolicyWidget(
            onAccepted: () async {
              // TODO: Save that the user has accepted the policy
              // For example, using shared_preferences:
              // SharedPreferences prefs = await SharedPreferences.getInstance();
              // await prefs.setBool('hasAcceptedPolicy', true);
              await _setHasAcceptedPolicy(true);
              // You might want to navigate away or update UI accordingly
            },
          );
        },
      );
    }
  }

  // Placeholder for getting first time status
  Future<bool> _getIsFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // If 'hasAcceptedPolicy' is not set, it means it's the first time or policy was never accepted.
    return !(prefs.getBool('hasAcceptedPolicy') ?? false);
  }

  // Placeholder for saving policy acceptance
  Future<void> _setHasAcceptedPolicy(bool accepted) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasAcceptedPolicy', accepted);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7BB027);
    const Color lightGreenButton = Color(0xFFC4FF62);
    const Color socialButtonBg = Color.fromARGB(150, 255, 255, 255);
    const Color socialButtonFg = Colors.black87;
    const Color emailButtonBg = lightGreenButton;
    const Color emailButtonFg = Colors.black;
    const Color textColor = Colors.white;
    const Color secondaryTextColor = Colors.white70;
    const Color footerLinkColor = Colors.white;

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundWidget(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/movliq_withtext.png',
                      height: 100,
                    ),
                    const SizedBox(height: 60),
                    FontWidget(
                      text: 'Daha Çok Hareket,',
                      styleType: TextStyleType.titleLarge,
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.start,
                    ),
                    FontWidget(
                      text: 'Daha Çok Kazanç',
                      styleType: TextStyleType.titleLarge,
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 48),
                    FontWidget(
                      text:
                          'Movliq’te ödüller, fırsatlar ve eğlence; hepsi seni bir adım uzaklıkta bekliyor!',
                      styleType: TextStyleType.bodyMedium,
                      color: secondaryTextColor,
                      fontSize: 18,
                      textAlign: TextAlign.center,
                    ),
                    /* const SizedBox(height: 32),
                  _buildSocialButton(
                    icon: FontAwesomeIcons.google,
                    text: 'Google ile Giriş   ',
                    onPressed: () {
                      // TODO: Implement Google login
                    },
                    bgColor: const Color.fromARGB(80, 255, 255, 255),
                    fgColor: const Color.fromARGB(255, 255, 255, 255),
                  ),
                  const SizedBox(height: 16),
                  _buildSocialButton(
                    icon: FontAwesomeIcons.facebookF,
                    text: 'Facebook ile Giriş',
                    onPressed: () {
                      // TODO: Implement Facebook login
                    },
                    bgColor: const Color.fromARGB(80, 255, 255, 255),
                    fgColor: const Color.fromARGB(255, 255, 255, 255),
                  ),
                  const SizedBox(height: 16),
                  _buildSocialButton(
                    icon: FontAwesomeIcons.apple,
                    text: 'Apple ile Giriş      ',
                    onPressed: () {
                      // TODO: Implement Apple login
                    },
                    bgColor: const Color.fromARGB(80, 255, 255, 255),
                    fgColor: const Color.fromARGB(255, 255, 255, 255),
                  ),*/
                    const SizedBox(height: 246),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emailButtonBg,
                          foregroundColor: emailButtonFg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginInputScreen(),
                            ),
                          );
                        },
                        child: FontWidget(
                            text: 'E-posta İle Devam Et',
                            styleType: TextStyleType.bodyLarge,
                            color: emailButtonFg,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: FontWidget(
                              text: 'Need Help?',
                              styleType: TextStyleType.bodyMedium,
                              color: Color.fromARGB(132, 255, 255, 255)),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {},
                          child: FontWidget(
                              text: 'Privacy Policy',
                              styleType: TextStyleType.bodyMedium,
                              color: Color.fromARGB(132, 255, 255, 255)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    required Color bgColor,
    required Color fgColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: FaIcon(icon, size: 20, color: fgColor),
        label: FontWidget(
            text: text,
            styleType: TextStyleType.bodyMedium,
            color: fgColor,
            fontWeight: FontWeight.w500),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
