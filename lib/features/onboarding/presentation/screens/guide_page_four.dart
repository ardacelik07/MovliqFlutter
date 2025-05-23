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

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
              height:
                  60), // Üstteki noktalar ve X butonu için daha fazla boşluk (noktalar artık yukarıda)
          Column(
            children: [
              Text(
                'ÖZEL ODALARLA',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 34, // Font boyutunu biraz ayarladım
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Fontu ekledikten sonra bu satırı aktif edin
                ),
              ),
              Text(
                'EĞLENCEYİ ZİRVEYE',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Fontu ekledikten sonra bu satırı aktif edin
                ),
              ),
              Text(
                'TAŞI!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Fontu ekledikten sonra bu satırı aktif edin
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images/userguide4.png', // Yeni resim yolu
            height: screenSize.height * 0.35, // Resim boyutunu biraz ayarladım
            fit: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Arkadaşlarınla kendi yarışınızı başlatmak artık çok kolay! Movliq\'te özel odalar sayesinde sadece davet ettiğin kişilerle yarışabilir, kendi kurallarınızı belirleyerek eğlenceyi kişiselleştirebilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                // Coco Gothic alternatifi
                fontSize: 17, // Font boyutunu biraz ayarladım
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 100), // Alttaki buton için boşluk
        ],
      ),
    );
  }
}
