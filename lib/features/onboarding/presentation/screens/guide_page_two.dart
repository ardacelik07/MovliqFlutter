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

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
              height: 40), // Üstteki noktalar ve X butonu için boşluk bırakır
          Column(
            children: [
              Text(
                'CANLI YARIŞLARA',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 36, // Biraz küçülttüm sığması için
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              Text(
                'KATILMAK ÇOK KOLAY!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 36, // Biraz küçülttüm sığması için
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images/buttonwomen.png', // Yeni resim yolu
            height: screenSize.height * 0.4, // Resim boyutunu ayarla
            fit: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Ana sayfadaki Movliq butonuna tıkla, canlı yarışın eğlenceli kapışmasına sen de katıl! İster arkadaşların ile istersen uygulamadaki diğer rakiplerin ile rekabetin sınırlarını zorla.',
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
