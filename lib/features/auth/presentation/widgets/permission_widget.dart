import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionWidget extends StatelessWidget {
  const PermissionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(0, 0, 0, 0), // Semi-transparent white
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                ),
              ],
            ),
            // Image at the top
            Image.asset(
              'assets/images/permission.png', // Provided image path
              height: MediaQuery.of(context).size.height *
                  0.3, // Adjust height as needed
            ),
            // Spacer to push the black card down a bit if needed, or adjust image size
            // SizedBox(height: 20),

            // Black card container
            Container(
              width: MediaQuery.of(context).size.width *
                  0.75, // 85% of screen width
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20.0), // Rounded corners
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Başlamadan Önce Küçük Bir Rica!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bangers(
                      color: Colors.white,
                      fontSize: 26, // Adjusted for visibility
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yarış başlasın mı?\nAma önce birkaç küçük izin lazım.\nSonrası zaten bol hareket, bol heyecan!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bangers(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      height: 1.4, // Line height
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFA8E04E), // Light green button color
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      textStyle: GoogleFonts.bangers(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () async {
                      // Open app settings
                      await openAppSettings();
                    },
                    child: Text(
                      'Ayarlara Git',
                      style: GoogleFonts.bangers(
                          color: Colors.black), // Explicitly set text color
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to open app settings (consider moving to a utility class)
// Future<void> openAppSettings() async {
//   if (!await launchUrl(Uri.parse('app-settings:'))) { // Standard URL scheme for settings
//     // Fallback for specific platforms if needed, or show error
//     print("Could not open app settings."); 
//   }
// }

// --- Example usage: ---
// You might show this widget as a dialog or a full screen
// when permissions are denied and you want to guide the user.

// void showPermissionGuidanceDialog(BuildContext context) {
//   showDialog(
//     context: context,
//     builder: (BuildContext context) {
//       return const PermissionWidget(); 
//     },
//   );
// }
