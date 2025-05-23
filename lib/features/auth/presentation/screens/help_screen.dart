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
        'question': 'Movliq Nedir?',
        'answer':
            '''Movliq, yürüyüşü ve koşuyu oyunlaştırarak kullanıcıları gerçek zamanlı yarışlara dahil eden, adımlarını mCoin\'e ve ödüllere dönüştüren yenilikçi bir mobil uygulamadır. Sporu yalnızca fiziksel değil, aynı zamanda sosyal ve eğlenceli bir deneyime dönüştürür.

• Gerçek zamanlı yürüyüş/koşu yarışları
• Arkadaşlarla özel odalarda yarışma
• Solo (tek başına) mod
• Ödül sistemi ve coin kazanımı
• Sosyal etkileşim, kültür ve motivasyon''',
        'isExpanded': true,
      },
      {
        'question': 'Canlı Yarış Nasıl Çalışır?',
        'answer':
            '''Kullanıcı, uygulama üzerinden canlı yarış lobisine katılırken yarışın türünü (iç veya dış mekân) ve süresini seçer. Sistem, aynı yarış ayarlarına sahip diğer kullanıcılarla eşleştirme yapar veya kullanıcı yeni bir yarış başlatarak oda oluşturabilir.
Tüm yarışmacılar belirlenen saatte veya "başlat" komutuyla aynı anda yarışa başlar. Uygulama, yarış süresi boyunca tüm katılımcıların adım sayısı, hız, ve mesafe verilerini gerçek zamanlı takip eder. Yarış bitiminde sistem verileri analiz eder ve bir sıralama oluşturur.İlk üçe giren kullanıcılar mCoin ile ödüllendirilir. Aynı zamanda özel başarılar ve görevler de ek coin kazanımı sağlayabilir.

• Gerçek zamanlı süre ve takip
• Adım, mesafe ve hız bazlı skor
• Yarış sonunda sıralama + coin/ödül dağıtımı
• Performansına göre günlük başarılar
• Liderlik tabloları ile rekabet duygusu''',
        'isExpanded': true,
      },
      {
        'question': 'Solo Mod',
        'answer':
            '''Kullanıcı, herhangi bir zaman kısıtlaması olmadan tek başına koşu veya yürüyüşe başlayabilir. Uygulama, kullanıcının hareket verilerini (adım, hız, mesafe) arka planda anlık olarak takip eder. Süre ve mesafe hedefi kullanıcıya bağlıdır, istediği yerde istediği zaman performansını ortaya koyabilir.
Kayıt edilen yürüyüş veya koşu aktivitleri sonucunda kullanıcı mCoin kazanır ve ilerleme kaydeder.
Yarışma havası olmasa da, kullanıcı kendi gelişimini takip edebilir ve günlük/haftalık başarı hedeflerini tamamlayarak mCoin ve ödüller kazanabilir.

• Kullanıcı dilediği zaman "Solo Mod"u başlatır
• Sistem adım, hız ve mesafeyi anlık olarak izler
• Her hareket ödül potansiyeli taşır
• Günlük bireysel görevler tamamlandıkça mCoin kazanılır
• İstatistik sayfasında kişisel gelişim takip edilir''',
        'isExpanded': true,
      },
      {
        'question': 'Sadece Uygulama Değil, Bir Kültür',
        'answer':
            '''Movliq, sadece bir fitness uygulaması değil; kazanmak, paylaşmak ve sosyalleşmek isteyenlerin buluşma noktasıdır.
Burada attığın her adım sadece fiziksel bir hareket değil; bir bağ kurma, bir yaşam tarzı oluşturma ve ilham verme fırsatıdır.
Her yarış, bir bağlantı; her adım, daha aktif bir hayatın parçası!
Movliq Kültürünün Temel Taşları:
• Topluluk Ruhu: Birlikte hareket etmek, birlikte motive olmak
• Paylaşmak: Kazandığını sadece kendin için değil, ilham olmak için de kullan
• Etkileşim: Arkadaşlarını davet et, özel odalarda yarış, deneyimini paylaş
• Motivasyon: Her gün, bir öncekinden daha iyi olmak için bir fırsat
• Erişilebilirlik: Profesyonel atlet olman gerekmez sadece harekete geç!''',
        'isExpanded': true,
      },
      {
        'question': 'Ödül Sistemi & mCoin',
        'answer':
            '''Ne kadar çok hareket edersen, o kadar çok kazanırsın! mCoin, movliq evreninde hareketin karşılığıdır. Attığın her adım, çıktığın her yarış, gösterdiğin her performans sana mCoin olarak geri döner.
Kazandığın mCoin\'leri Movliq mağazasında; kuponlara, özel kampanyalara, sürpriz hediyelere ve daha fazlasına dönüştürebilirsin.
Nasıl Kazanırsın?
• Canlı yarışlara katılarak dereceye gir
• Solo modda aktif ol
• Günlük,haftalık,aylık hedefleri tamamla
• Özel görevlerde başarı göster
• Ortak havuz yarışlarında birinci ol''',
        'isExpanded': true,
      },
      {
        'question': 'Bireysel & Sosyal Deneyim',
        'answer':
            '''İster tek başına, ister arkadaşlarınla yarış! Movliq\'te özel yarış odaları oluşturabilir, kodla arkadaşlarını davet edebilir, toplulukla etkileşime geçebilir, birlikte motive olabilirsiniz.
Sosyal Kullanım (Özel Odalar & Topluluk):
• Özel yarış odaları oluşturabilir, kodla arkadaşlarını davet edebilirsin
• Aynı anda yarışarak birlikte hareket etmenin keyfini yaşarsın
• Grup içi sıralama ile rekabet artar, motivasyon yükselir
• Haftalık etkinlikler, meydan okumalar ve sosyal görevlerle toplulukla bağ kurarsın
• Paylaşım, destek ve birlikte kazanma kültürü ön plandadır''',
        'isExpanded': true,
      },
      {
        'question': 'Ortak Havuz Yarışları',
        'answer':
            '''Arkadaşlarınla heyecanı artırmak için özel odalarda bir mCoin sayısı belirlenir. Her katılımcı istedikleri miktarda mCoin ile yarışa dahil olur.
Yarış sonunda birinci olan kullanıcı, tüm mCoinleri toplar!
Nasıl İşler?
• Yarış başında her katılımcı istediği mCoin\'i ile yarışa katılım yapar
• Performansınıza göre sıralama belirlenir
• Kazanan kişi tüm mCoin havuzunu alır
• Diğer katılımcılar mCoinlerini kaybeder''',
        'isExpanded': true,
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
          style: TextStyle(color: textColor, fontSize: 17),
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
              color: textColor, fontSize: 17, fontWeight: FontWeight.w500),
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
