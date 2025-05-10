import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/background_widget.dart';
import '../widgets/social_login_button.dart';
import '../widgets/tagline_widget.dart';
import '../widgets/footer_widget.dart';
import '../screens/register_screen.dart';
import '../screens/login_input_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const BackgroundWidget(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      Image.asset(
                        'assets/images/movliq_withtext.png',
                        height: 100,
                      ),
                      const SizedBox(height: 60),
                      const Text(
                        'Move more, Earn more',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      const Text(
                        'Join a global running community and\nchallenge yourself every day.',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 18,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
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
                      ),
                      const SizedBox(height: 24),
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
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                          child: const Text('E-posta ile Devam Et'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Need Help?',
                              style: TextStyle(
                                  color: Color.fromARGB(132, 255, 255, 255)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                  color: Color.fromARGB(132, 255, 255, 255)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
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
        label: Text(text),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
