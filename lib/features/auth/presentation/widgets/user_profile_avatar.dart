import 'package:flutter/material.dart';

class UserProfileAvatar extends StatelessWidget {
  final String? imageUrl; // Null olabilir
  final double radius;
  final String defaultImageAsset =
      'assets/images/runningman.png'; // Varsayılan asset

  const UserProfileAvatar({
    super.key, // Use super parameter for Key
    required this.imageUrl,
    this.radius = 25.0, // Varsayılan bir boyut
  });

  @override
  Widget build(BuildContext context) {
    // Check if imageUrl is not null and not an empty string
    final bool hasValidUrl = imageUrl?.isNotEmpty ?? false;

    return CircleAvatar(
      radius: radius,
      backgroundImage: hasValidUrl
          ? NetworkImage(imageUrl!) // Use NetworkImage
          : AssetImage(defaultImageAsset) as ImageProvider, // Cast AssetImage
      // Optional: Add error handling for NetworkImage if needed
      // onBackgroundImageError: hasValidUrl ? (exception, stackTrace) {
      //   print("Error loading profile image: $exception");
      //   // Optionally show default image on error, but backgroundImage setter handles this implicitly if NetworkImage fails
      // } : null,
      backgroundColor: Colors.grey[800], // Darker background for dark theme
    );
  }
}
