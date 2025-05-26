import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageSix extends StatelessWidget {
  const GuidePageSix({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor =
        Color(0xFFC9FB4B); // Same vibrant green as other pages
    const Color textColor = Colors.black;
    // const Color buttonTextColor = Colors.white; // Not used in this refactor
    // const Color buttonColor = Colors.black; // Not used in this refactor

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenSize.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.start, // Changed from spaceBetween
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20), // Consistent spacing
                  Column(
                    children: [
                      Text(
                        'HAZIRSAN!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'ŞİMDİ SAHNE SENİN',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Image.asset(
                    'assets/images/userguide6.png',
                    height: screenSize.height * 0.35,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Artık nasıl oynanacağını biliyorsun. Şimdi harekete geç, yarışlara katıl, ödülleri topla!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60), // Adjusted bottom spacing
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
