import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageFour extends StatelessWidget {
  const GuidePageFour({super.key});

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
                mainAxisAlignment:
                    MainAxisAlignment.start, // Changed from spaceBetween
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20), // Consistent spacing
                  Column(
                    children: [
                      Text(
                        'ÖZEL ODALARLA',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'EĞLENCEYİ ZİRVEYE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'TAŞI!',
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
                    'assets/images/userguide4.png',
                    height: screenSize.height * 0.35,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Arkadaşlarınla kendi yarışınızı başlatmak artık çok kolay! Movliq\'te özel odalar sayesinde sadece davet ettiğin kişilerle yarışabilir, kendi kurallarınızı belirleyerek eğlenceyi kişiselleştirebilirsiniz.',
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
