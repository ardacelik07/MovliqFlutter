import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts paketini içe aktardık

class GuidePageSix extends StatelessWidget {
  const GuidePageSix({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor =
        Color(0xFFC9FB4B); // Same vibrant green as other pages
    const Color textColor = Colors.black;
    const Color buttonTextColor = Colors.white;
    const Color buttonColor = Colors.black;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
              height: 20), // Adjusted spacing for elements at the top
          Column(
            children: [
              Text(
                'HAZIRSAN!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Uncomment after adding the font
                ),
              ),
              Text(
                'ŞİMDİ SAHNE SENİN',
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  // Cheddar alternatifi
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.1,
                  // fontFamily: 'Cheddar', // Uncomment after adding the font
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images/userguide6.png', // Path to the new image
            height: screenSize.height * 0.35, // Adjust image size as needed
            fit: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Artık nasıl oynanacağını biliyorsun. Şimdi harekete geç, yarışlara katıl, ödülleri topla!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                // Coco Gothic alternatifi
                fontSize: 17,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 20), // Spacing at the bottom
        ],
      ),
    );
  }
}
