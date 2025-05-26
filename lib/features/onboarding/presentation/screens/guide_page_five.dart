import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageFive extends StatelessWidget {
  const GuidePageFive({super.key});

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
                      Text(
                        'SOLO MOD',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'KENDİ YOLUNUN',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'ŞAMPİYONU OL!',
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
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/userguide5.png',
                    height: screenSize.height * 0.35,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Solo mod ile istediğin hızda hareket et koş ya da yürü kurallar senin! daha fazla hareket daha fazla kazanım',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        color: textColor,
                        height: 1.4,
                      ),
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
