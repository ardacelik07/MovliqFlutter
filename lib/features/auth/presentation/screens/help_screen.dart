import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:url_launcher/url_launcher.dart'; // E-posta için gerekebilir

// Email gönderme fonksiyonunu widget dışında tanımla
Future<void> _launchEmail() async {
  // const String email = 'destek@example.com'; // TODO: Replace with actual support email
  // final Uri emailLaunchUri = Uri(
  //   scheme: 'mailto',
  //   path: email,
  //   query: 'subject=Yardım Talebi&body=Merhaba,',
  // );
  // try {
  //   await launchUrl(emailLaunchUri);
  // } catch (e) {
  //   print('Could not launch email: $e');
  //   // Show error to user
  // }
  print('Email button pressed'); // Placeholder action
}

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  // Renkler ve FAQ verisi artık build metodunda tanımlanacak
  // --- Theme Colors (Match other screens) ---
  // final Color _backgroundColor = Colors.black;
  // final Color _cardColor = Colors.grey[900]!;
  // final Color _textColor = Colors.white;
  // final Color _secondaryTextColor = Colors.grey[400]!;
  // final Color _accentColor = const Color(0xFFB2FF59); // Light green accent
  // final Color _labelColor = Colors.grey[500]!;

  // Placeholder FAQ data
  // final List<Map<String, dynamic>> _faqs = [...];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Renkleri ve FAQ'ları burada tanımla
    final Color backgroundColor = Colors.black;
    final Color cardColor = Colors.grey[900]!;
    final Color textColor = Colors.white;
    final Color secondaryTextColor = Colors.grey[400]!;
    final Color accentColor = const Color(0xFFB2FF59);
    final Color labelColor = Colors.grey[500]!;

    final List<Map<String, dynamic>> faqs = [
      {
        'question': 'Puanlar nasıl kazanılır?',
        'answer': 'Puan kazanma detayları burada açıklanacak.',
        'isExpanded': false,
      },
      {
        'question': 'Yarışa nasıl katılırım?',
        'answer': 'Yarışa katılım adımları burada yer alacak.',
        'isExpanded': false,
      },
      {
        'question': 'Kupon kodumu nasıl kullanırım?',
        'answer': 'Kupon kodu kullanımı hakkında bilgi burada olacak.',
        'isExpanded': false,
      },
      {
        'question': 'Koşu verilerimi nasıl senkronize edebilirim?',
        'answer':
            'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.',
        'isExpanded': true, // This one is expandable
      },
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Yardım & Destek',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sorularınız mı var? Size yardımcı olmaktan mutluluk duyarız.',
              style: TextStyle(color: secondaryTextColor, fontSize: 15),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Bize Ulaşın', textColor), // Pass color
            ElevatedButton.icon(
              onPressed: _launchEmail, // Global fonksiyonu çağır
              icon:
                  Icon(Icons.email_outlined, color: backgroundColor, size: 20),
              label: Text('E-posta Gönder',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: backgroundColor)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: backgroundColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle(
                'Sıkça Sorulan Sorular', textColor), // Pass color
            // Build FAQ items
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length, // build metodu içindeki listeyi kullan
              itemBuilder: (context, index) {
                final faq = faqs[index];
                if (faq['isExpanded']) {
                  return _buildFaqExpansionTile(
                    faq['question'],
                    faq['answer'],
                    cardColor, // Pass color
                    textColor, // Pass color
                    secondaryTextColor, // Pass color
                    accentColor, // Pass color
                  );
                } else {
                  return _buildFaqNavigationTile(
                    faq['question'],
                    cardColor, // Pass color
                    textColor, // Pass color
                    accentColor, // Pass color
                  );
                }
              },
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'Destek taleplerinize en kısa sürede yanıt vereceğiz.',
                style: TextStyle(color: labelColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget'lar artık renkleri parametre olarak almalı
  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // For non-expandable FAQ items
  Widget _buildFaqNavigationTile(
    String question,
    Color cardColor,
    Color textColor,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          question,
          style: TextStyle(color: textColor, fontSize: 15),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: accentColor, size: 16),
        onTap: () {
          // TODO: Implement navigation or action for this FAQ
          print('Tapped on: $question');
        },
      ),
    );
  }

  // For expandable FAQ item
  Widget _buildFaqExpansionTile(
    String question,
    String answer,
    Color cardColor,
    Color textColor,
    Color secondaryTextColor,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ExpansionTile(
        iconColor: accentColor,
        collapsedIconColor: accentColor,
        title: Text(
          question,
          style: TextStyle(
              color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0)
                .copyWith(top: 0),
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: <Widget>[
          Text(
            answer,
            style:
                TextStyle(color: secondaryTextColor, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
