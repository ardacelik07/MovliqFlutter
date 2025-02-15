import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/background_widget.dart';
import '../widgets/social_login_button.dart';
import '../widgets/tagline_widget.dart';
import '../widgets/footer_widget.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundWidget(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/images/movliq_beyaz.png',
                    height: 60,
                  ),
                  const SizedBox(height: 24),
                  const TaglineWidget(),
                  const SizedBox(height: 48),
                  SocialLoginButton.google(
                    onPressed: () {
                      // TODO: Implement Google login
                    },
                  ),
                  const SizedBox(height: 16),
                  SocialLoginButton.facebook(
                    onPressed: () {
                      // TODO: Implement Facebook login
                    },
                  ),
                  const SizedBox(height: 16),
                  SocialLoginButton.microsoft(
                    onPressed: () {
                      // TODO: Implement Microsoft login
                    },
                  ),
                  const Spacer(flex: 3),
                  const FooterWidget(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
