import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/font_widget.dart';

// HelpScreen'deki global fonksiyonu kullanabiliriz veya buraya taşıyabilir/import edebiliriz.
// Şimdilik HelpScreen'deki tanımı varsayalım veya gerekirse buraya kopyalayalım.
// Eğer HelpScreen'den import edilecekse:
// import 'help_screen.dart' show _launchEmail; // Bu şekilde sadece fonksiyon import edilir.

// Geçici olarak fonksiyonu buraya kopyalayalım (en iyi pratik olmayabilir)
Future<void> _launchPolicyEmail() async {
  print('Policy Email button pressed'); // Placeholder action
  // Gerçek e-posta gönderme mantığı (url_launcher ile) HelpScreen'deki gibi eklenebilir.
}

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Renkleri burada tanımla (Diğer ekranlarla tutarlı)
    final Color backgroundColor = Colors.black;
    // final Color cardColor = Colors.grey[900]!; // Bu ekranda kart yok
    final Color textColor = Colors.white;
    final Color secondaryTextColor = Colors.grey[400]!;
    final Color accentColor = const Color(0xFFB2FF59);
    final Color labelColor = Colors.grey[500]!;
    final Color titleColor = accentColor; // Başlıklar için vurgu rengi

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: FontWidget(
          text: 'Gizlilik Politikası',
          styleType: TextStyleType.labelLarge,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
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
            FontWidget(
              text: 'Verileriniz bizim için önemli. İşte nasıl koruyoruz:',
              styleType: TextStyleType.labelLarge,
              color: secondaryTextColor,
              fontSize: 15,
            ),
            const SizedBox(height: 24),
            _buildPolicySection(
              title: 'Veri Toplama',
              titleColor: titleColor,
              content:
                  'Uygulamamızı kullanırken, size daha iyi hizmet verebilmek için bazı kişisel verilerinizi topluyoruz. Bu veriler şunları içerir:',
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              bulletPoints: [
                'Koşu aktiviteleriniz ve rotalarınız',
                'Temel profil bilgileriniz',
                'Cihaz ve uygulama kullanım verileri',
              ],
            ),
            const SizedBox(height: 24),
            _buildPolicySection(
              title: 'Veri Kullanımı',
              titleColor: titleColor,
              content:
                  'Topladığımız verileri aşağıdaki amaçlar için kullanıyoruz:',
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              bulletPoints: [
                'Hizmet kalitesini iyileştirmek',
                'Kişiselleştirilmiş antrenman planları oluşturmak',
                'Uygulama performansını optimize etmek',
              ],
            ),
            const SizedBox(height: 24),
            _buildPolicySection(
              title: 'Üçüncü Taraflarla Paylaşım',
              titleColor: titleColor,
              content:
                  'Verileriniz, yalnızca sizin açık rızanızla ve hizmet kalitesini artırmak amacıyla güvenilir üçüncü taraf hizmet sağlayıcılarıyla paylaşılabilir.',
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              // Bu bölümde madde işareti yok
            ),
            const SizedBox(height: 24),
            _buildPolicySection(
              title: 'Haklarınız',
              titleColor: titleColor,
              content: 'KVKK kapsamında aşağıdaki haklara sahipsiniz:',
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              bulletPoints: [
                'Verilerinize erişim hakkı',
                'Düzeltme talep etme hakkı',
                'Silme talep etme hakkı',
                'İşlemeyi sınırlandırma hakkı',
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Politika bölümlerini oluşturmak için yardımcı widget
  Widget _buildPolicySection({
    required String title,
    required Color titleColor,
    required String content,
    required Color textColor,
    required Color secondaryTextColor,
    List<String>? bulletPoints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FontWidget(
          text: title,
          styleType: TextStyleType.labelLarge,
          color: titleColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        FontWidget(
          text: content,
          styleType: TextStyleType.labelLarge,
          color: secondaryTextColor,
          fontSize: 15,
        ),
        if (bulletPoints != null && bulletPoints.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bulletPoints
                  .map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: FontWidget(
                          text: '• $point', // Madde işareti eklendi
                          styleType: TextStyleType.labelLarge,
                          color: secondaryTextColor,
                          fontSize: 15,
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
