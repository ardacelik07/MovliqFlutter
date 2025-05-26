import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageLocation extends StatelessWidget {
  const GuidePageLocation({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor = Color(0xFFC9FB4B);
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
                        'SANA EN İYİ DENEYİMİ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'SUNMAMIZA İZİN VERİR MİSİN?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Image.asset(
                    'assets/images/locationpermission.png',
                    height: screenSize.height * 0.4,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24), // Consistent spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Adım ve konum bilgilerinle yarışları doğru takip edebilir, ödülleri doğru şekilde ulaştırabiliriz. Endişelenme, verilerin bizim için çok değerli ve güvende! Bu izinler olmadan bazı keyifli özellikleri ne yazık ki sunamıyoruz.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
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
