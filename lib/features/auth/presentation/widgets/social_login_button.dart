import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocialLoginButton extends StatelessWidget {
  final String text;
  final String iconPath;
  final Color color;
  final VoidCallback onPressed;

  const SocialLoginButton._({
    required this.text,
    required this.iconPath,
    required this.color,
    required this.onPressed,
  });

  factory SocialLoginButton.google({required VoidCallback onPressed}) {
    return SocialLoginButton._(
      text: 'Continue with Google     ',
      iconPath: 'assets/icons/google.svg',
      color: const Color.fromARGB(26, 0, 0, 0),
      onPressed: onPressed,
    );
  }

  factory SocialLoginButton.facebook({required VoidCallback onPressed}) {
    return SocialLoginButton._(
      text: 'Continue with Facebook',
      iconPath: 'assets/icons/facebook.svg',
      color: const Color.fromARGB(26, 0, 0, 0),
      onPressed: onPressed,
    );
  }

  factory SocialLoginButton.microsoft({required VoidCallback onPressed}) {
    return SocialLoginButton._(
      text: 'Continue with Microsoft',
      iconPath: 'assets/icons/microsoft.svg',
      color: const Color.fromARGB(26, 0, 0, 0),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == Colors.white ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              height: 24,
              width: 24,
              colorFilter: color == Colors.white
                  ? const ColorFilter.mode(Colors.black, BlendMode.srcIn)
                  : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
