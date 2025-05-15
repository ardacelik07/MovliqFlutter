import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_data_provider.dart';

class EarnCoinPopup extends ConsumerWidget {
  final double earnedCoin;
  final VoidCallback onGoHomePressed;

  const EarnCoinPopup({
    super.key,
    required this.earnedCoin,
    required this.onGoHomePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor:
          Colors.transparent, // Make default dialog background transparent
      insetPadding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // Dark background similar to image
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fit content vertically
          children: [
            // Title
            const Text(
              'Tebrikler 🎉',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Image
            Transform.scale(
              scale: 1.2,
              child: Image.asset(
                'assets/images/coinchest2.png', // Ensure this path is correct
                height: screenHeight * 0.3, // <-- 0.25'ten 0.3'e çıkarıldı
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error_outline,
                      color: Colors.red, size: 50); // Placeholder on error
                },
              ),
            ),
            const SizedBox(height: 24),

            // Earned Coin Text - double'ı 2 ondalık basamakla göster
            Text(
              '+${earnedCoin.toStringAsFixed(2)} M-Coin\nKazandınız', // .toInt() yerine .toStringAsFixed(2) kullanıldı
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Or light green Color(0xFFC4FF62)?
                height: 1.2, // Line height
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtitle
            const Text(
              'Daha fazla yarışa katıl daha çok kazan',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Home Button
            ElevatedButton(
              onPressed: () {
                ref.read(userDataProvider.notifier).fetchCoins();
                onGoHomePressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.black, // Black text
                minimumSize: Size(screenWidth * 0.6, 50), // Button size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.0), // Rounded corners
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Ana Sayfaya Dön'),
            ),

            // Optional: Add the "Ödüller İncelemek İster Misin?" text if needed
            // const SizedBox(height: 24),
            // const Text(
            //   'Ödüller İncelemek\nİster Misin?',
            //   style: TextStyle(
            //     fontSize: 14,
            //     color: Colors.grey,
            //   ),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
      ),
    );
  }
}

// --- Nasıl Kullanılır Örneği ---
// Bu popup'ı göstermek için:
/*
void _showCoinPopup(BuildContext context, int coins) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (BuildContext dialogContext) {
      return EarnCoinPopup(
        earnedCoin: coins,
        onGoHomePressed: () {
          Navigator.of(dialogContext).pop(); // Close the popup
          // TODO: Ana sayfaya yönlendirme ekle (örn: context.go('/home'))
        },
      );
    },
  );
}

// Örneğin RecordScreen'de coin kazanıldıktan sonra:
// final earnedAmount = (earnedCoinResult['earnedCoin'] as double? ?? 0.0);
// if (earnedAmount > 0) {
//   _showCoinPopup(context, earnedAmount);
// }
*/
