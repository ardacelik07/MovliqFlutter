import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageOne extends StatelessWidget {
  const GuidePageOne({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor =
        Color(0xFFC9FB4B); // Resimdeki canlı yeşil tonu
    const Color textColor = Colors.black;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
              height: 20), // Üstteki noktalar ve X butonu için boşluk bırakır
          Column(
            children: [
              Text(
                'HAREKETE GEÇ,',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.1, // Satır yüksekliğini azaltmak için
                ),
              ),
              Text(
                'KAZANMAYA BAŞLA!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.1, // Satır yüksekliğini azaltmak için
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images/userguide1.png', // Güncellenmiş resim yolu
            height: screenSize.height * 0.4, // Resim boyutunu ayarla
            fit: BoxFit.contain,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Movliq; koşu, yürüyüş ve tempolu aktivitelere dayalı canlı yarışlarla seni ödüllendiren bir spor platformudur.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                // Coco Gothic alternatifi
                fontSize: 20, // Metin boyutunu biraz büyüttüm
                color: Colors.black,
                height: 1.4, // Satır aralığını artırdım
              ),
            ),
          ),
          const SizedBox(
              height: 100), // Alttaki buton ve sayfa indikatörleri için boşluk
        ],
      ),
    );
  }
}
