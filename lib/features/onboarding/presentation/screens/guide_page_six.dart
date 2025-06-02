import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // Commented out
import '../../../auth/presentation/widgets/font_widget.dart'; // Added FontWidget import

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
                      FontWidget(
                        text: 'HAZIRSAN!',
                        styleType:
                            TextStyleType.titleLarge, // Adjusted for Bangers
                        textAlign: TextAlign.center,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        // height: 1.1, // FontWidget does not directly support height
                      ),
                      FontWidget(
                        text: 'ŞİMDİ SAHNE SENİN',
                        styleType:
                            TextStyleType.titleLarge, // Adjusted for Bangers
                        textAlign: TextAlign.center,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        // height: 1.1, // FontWidget does not directly support height
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
                    child: FontWidget(
                      text:
                          'Artık nasıl oynanacağını biliyorsun. Şimdi harekete geç, yarışlara katıl, ödülleri topla!',
                      styleType:
                          TextStyleType.bodyLarge, // Adjusted for Poppins
                      textAlign: TextAlign.center,
                      fontSize: 17,
                      color: textColor,
                      // height: 1.4, // FontWidget does not directly support height
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
