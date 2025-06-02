import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String? title; // Optional title
  final String? message; // Optional message

  const NetworkErrorWidget({
    super.key,
    required this.onRetry,
    this.title, // Make title optional
    this.message, // Make message optional
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Use provided title/message or default network error text
    final String displayTitle = title ?? 'Network unavailable';
    final String displayMessage =
        message ?? 'Please check your data connection and try again.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/images/sifremiunuttum2.png',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 24.0),
            Text(
              displayTitle, // Use displayTitle
              style: GoogleFonts.bangers(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Ensure title is visible on black bg
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              displayMessage, // Use displayMessage
              style: GoogleFonts.bangers(
                fontSize: 16,
                color: Colors.grey[400], // Lighter grey for better visibility
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                // Keep the button style consistent for now
                backgroundColor:
                    Color(0xFFC4FF62), // Default primary (blueish?)
                foregroundColor: Colors.black, // Text on primary
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 12.0),
                textStyle: GoogleFonts.bangers(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
