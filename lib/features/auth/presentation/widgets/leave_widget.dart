import 'package:flutter/material.dart';

class LeaveWidget extends StatelessWidget {
  final String imagePath;
  final String title;
  final String message;
  final String confirmButtonText;
  final String cancelButtonText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const LeaveWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.message,
    required this.confirmButtonText,
    required this.cancelButtonText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Make dialog background transparent
      insetPadding: const EdgeInsets.all(20), // Padding around the dialog
      child: Stack(
        clipBehavior: Clip.none, // Allow image to overflow
        alignment: Alignment.topCenter,
        children: [
          // Dialog content card
          Container(
            margin: const EdgeInsets.only(top: 60), // Space for the image above
            padding: const EdgeInsets.only(
                top: 70,
                left: 24,
                right: 24,
                bottom: 24), // Padding inside the card
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), // Dark card background
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC4FF62),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          cancelButtonText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3A3C),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmButtonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Character image positioned at the top
          Positioned(
            top: -10, // Adjust this value to position the image correctly
            child: Image.asset(
              imagePath,
              height: 140, // Adjust height as needed
              width: 140, // Adjust width as needed
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to show the dialog (optional, but good practice)
Future<bool?> showLeaveConfirmationDialog({
  required BuildContext context,
  required String imagePath,
  required String title,
  required String message,
  String confirmButtonText = 'Çıkış Yap',
  String cancelButtonText = 'Devam Et',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // User must tap button!
    builder: (BuildContext dialogContext) {
      return LeaveWidget(
        imagePath: imagePath,
        title: title,
        message: message,
        confirmButtonText: confirmButtonText,
        cancelButtonText: cancelButtonText,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
        onCancel: () => Navigator.of(dialogContext).pop(false),
      );
    },
  );
}
