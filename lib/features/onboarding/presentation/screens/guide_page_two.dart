import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageTwo extends StatelessWidget {
  const GuidePageTwo({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor =
        Color(0xFFC9FB4B); // İlk sayfayla aynı canlı yeşil tonu
    const Color textColor = Colors.black;

    // Wrap with Scaffold, SafeArea, SingleChildScrollView, and ConstrainedBox
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenSize.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom, // Adjust for SafeArea
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.start, // Changed from spaceBetween
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                      height:
                          20), // Adjusted for consistent spacing with page one
                  Column(
                    children: [
                      Text(
                        'CANLI YARIŞLARA',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'KATILMAK ÇOK KOLAY!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Image.asset(
                    'assets/images/buttonwomen.png',
                    height: screenSize.height * 0.4,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Ana sayfadaki Movliq butonuna tıkla, canlı yarışın eğlenceli kapışmasına sen de katıl! İster arkadaşların ile istersen uygulamadaki diğer rakiplerin ile rekabetin sınırlarını zorla.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 60), // Adjusted bottom spacing for scrollability
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
