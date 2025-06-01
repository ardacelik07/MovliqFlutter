import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // Commented out
import '../../../auth/presentation/widgets/font_widget.dart'; // Added FontWidget import

class GuidePageThree extends StatelessWidget {
  const GuidePageThree({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor =
        Color(0xFFC9FB4B); // Diğer sayfalarla aynı canlı yeşil tonu
    const Color textColor = Colors.black;

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
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      FontWidget(
                        text: 'HER YARIŞTA',
                        styleType:
                            TextStyleType.titleLarge, // Adjusted for Bangers
                        textAlign: TextAlign.center,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        // height: 1.1, // FontWidget does not directly support height
                      ),
                      FontWidget(
                        text: 'M-COIN KAZAN!',
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
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/userguide3.png',
                    height: screenSize.height * 0.45,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FontWidget(
                      text:
                          'Yarışta gösterdiğin performansa göre mCoin kazan. mCoin\'leri profilinde biriktir ve mağazada özel ürünlere ve kuponlara erişim sağla.',
                      styleType:
                          TextStyleType.bodyLarge, // Adjusted for Poppins
                      textAlign: TextAlign.center,
                      fontSize: 18,
                      color: textColor,
                      // height: 1.4, // FontWidget does not directly support height
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
