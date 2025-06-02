import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // Commented out
import '../../../auth/presentation/widgets/font_widget.dart'; // Added FontWidget import
import '../../../auth/presentation/screens/tabs.dart';

class GuidePageOne extends ConsumerWidget {
  const GuidePageOne({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Size screenSize = MediaQuery.of(context).size;
    const Color backgroundColor = Color(0xFFC9FB4B); // Canlı yeşil
    const Color textColor = Colors.black;

    return WillPopScope(
      onWillPop: () async {
        ref.read(selectedTabProvider.notifier).state = 0;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TabsScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenSize.height,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.start, // Scroll için değiştirildi
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        FontWidget(
                          text: 'HAREKETE GEÇ,',
                          styleType:
                              TextStyleType.titleLarge, // Adjusted for Bangers
                          textAlign: TextAlign.center,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          // height: 1.1, // FontWidget does not directly support height, manage via line spacing if needed
                        ),
                        FontWidget(
                          text: 'KAZANMAYA BAŞLA!',
                          styleType:
                              TextStyleType.titleLarge, // Adjusted for Bangers
                          textAlign: TextAlign.center,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          // height: 1.1, // FontWidget does not directly support height
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Image.asset(
                      'assets/images/userguide1.png',
                      height: screenSize.height * 0.4,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: FontWidget(
                        text:
                            'Movliq; koşu, yürüyüş ve tempolu aktivitelere dayalı canlı ve eğlenceli meydan okumalarla seni ödüllendiren bir spor platformudur.',
                        styleType:
                            TextStyleType.bodyLarge, // Adjusted for Poppins
                        textAlign: TextAlign.center,
                        fontSize: 20,
                        color: textColor,
                        // height: 1.4, // FontWidget does not directly support height
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
