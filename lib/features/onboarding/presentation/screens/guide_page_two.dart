import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // Commented out
import '../../../auth/presentation/widgets/font_widget.dart'; // Added FontWidget import

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
                      FontWidget(
                        text: 'CANLI YARIŞLARA',
                        styleType:
                            TextStyleType.titleLarge, // Adjusted for Bangers
                        textAlign: TextAlign.center,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        // height: 1.1, // FontWidget does not directly support height
                      ),
                      FontWidget(
                        text: 'KATILMAK ÇOK KOLAY!',
                        styleType:
                            TextStyleType.titleLarge, // Adjusted for Bangers
                        textAlign: TextAlign.center,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        // height: 1.1, // FontWidget does not directly support height
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
                    child: FontWidget(
                      text:
                          'Ana sayfadaki Movliq butonuna tıkla, canlı yarışın eğlenceli kapışmasına sen de katıl! İster arkadaşların ile istersen uygulamadaki diğer rakiplerin ile rekabetin sınırlarını zorla.',
                      styleType:
                          TextStyleType.bodyLarge, // Adjusted for Poppins
                      textAlign: TextAlign.center,
                      fontSize: 18,
                      color: textColor,
                      // height: 1.4, // FontWidget does not directly support height
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
