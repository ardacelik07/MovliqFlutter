import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class TaglineWidget extends StatelessWidget {
  const TaglineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppConstants.tagline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black45,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.subTagline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ],
    );
  }
} 