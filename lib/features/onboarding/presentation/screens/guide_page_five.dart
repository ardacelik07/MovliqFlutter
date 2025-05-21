import 'package:flutter/material.dart';

class GuidePageFive extends StatelessWidget {
  const GuidePageFive({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor = Color(0xFFAEFF00); // Diğer sayfalarla aynı canlı yeşil tonu
    const Color textColor = Colors.black;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60), // Üstteki noktalar ve X butonu için daha fazla boşluk (noktalar artık yukarıda)
          Column(
            children: const [
              Text(
                'SOLO MOD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34, // Font boyutunu biraz ayarladım
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Fontu ekledikten sonra bu satırı aktif edin
                ),
              ),
              Text(
                'KENDİ YOLUNUN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Fontu ekledikten sonra bu satırı aktif edin
                ),
              ),
              Text(
                'ŞAMPİYONU OL!',
                textAlign: TextAlign.center,
                style: TextStyle(
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
            'assets/images/userguide5.png', // Yeni resim yolu
            height: screenSize.height * 0.35, // Resim boyutunu biraz ayarladım
            fit: BoxFit.contain,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Solo mod ile istediğin hızda hareket et koş ya da yürü kurallar senin! daha fazla hareket daha fazla kazanım',
              textAlign: TextAlign.center,
              style: TextStyle(
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