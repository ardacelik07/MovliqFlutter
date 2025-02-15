import 'package:flutter/material.dart';

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            // TODO: Implement help action
          },
          child: const Text(
            'Need Help?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        const Text(
          '|',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            // TODO: Implement privacy policy action
          },
          child: const Text(
            'Privacy Policy',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
} 