import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageThree extends StatelessWidget {
  const GuidePageThree({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor =
        Color(0xFFC9FB4B); // Diğer sayfalarla aynı canlı yeşil tonu
    const Color textColor = Colors.black;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
              height:
                  40), // Üstteki noktalar ve X butonu için boşluk (GuidingMainScreen'de X son sayfada gizli)
          Column(
            children: [
              Text(
                'HER YARIŞTA',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              Text(
                'M-COIN KAZAN!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images/userguide3.png', // Yeni resim yolu
            height: screenSize.height * 0.45, // Resim boyutunu biraz ayarladım
            fit: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Yarışta gösterdiğin performansa göre mCoin kazan. mCoin\'leri profilinde biriktir ve mağazada özel ürünlere ve kuponlara erişim sağla.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                // Coco Gothic alternatifi
                fontSize: 18,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(
              height: 120), // Alttaki buton ve sayfa indikatörleri için boşluk
        ],
      ),
    );
  }
}
