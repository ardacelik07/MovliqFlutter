import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/core/config/api_config.dart';
import 'package:my_flutter_project/core/services/http_interceptor.dart';
// import 'package:url_launcher/url_launcher.dart'; // E-posta için gerekebilir
import '../widgets/font_widget.dart';
import '../widgets/error_display_widget.dart'; // For ErrorDisplayWidget

// Updated _launchEmail function to show a dialog
Future<void> _launchEmail(BuildContext context, WidgetRef ref) async {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return _SupportEmailDialog(ref: ref);
    },
  );
}

class _SupportEmailDialog extends StatefulWidget {
  final WidgetRef ref;
  const _SupportEmailDialog({required this.ref});

  @override
  State<_SupportEmailDialog> createState() => _SupportEmailDialogState();
}

class _SupportEmailDialogState extends State<_SupportEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendSupportEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text;
      final message = _messageController.text;

      try {
        final response = await HttpInterceptor.post(
          Uri.parse('${ApiConfig.baseUrl}/User/send-support-email'),
          body: jsonEncode({'email': email, 'message': message}),
        );

        if (mounted) {
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: FontWidget(
                  text: 'Destek mesajınız başarıyla gönderildi.',
                  styleType: TextStyleType.bodyMedium,
                  color: Colors.black,
                ),
                backgroundColor: const Color(0xFFB2FF59), // accentColor
              ),
            );
            Navigator.of(context).pop(); // Close the dialog
          } else {
            final responseData = jsonDecode(response.body);
            final errorMessage = responseData['message'] ??
                'Destek mesajı gönderilirken bir hata oluştu. Kod: ${response.statusCode}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: ErrorDisplayWidget(errorObject: errorMessage),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: ErrorDisplayWidget(errorObject: e.toString()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Colors.grey[900]!;
    final Color textColor = Colors.white;
    final Color accentColor = const Color(0xFFB2FF59);
    final Color inputFillColor = Colors.grey[800]!;

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: FontWidget(
        text: 'Destek Talebi Oluştur',
        styleType: TextStyleType.titleMedium,
        color: textColor,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'E-posta Adresiniz',
                  labelStyle: TextStyle(color: accentColor.withOpacity(0.7)),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen e-posta adresinizi girin.';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Lütfen geçerli bir e-posta adresi girin.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _messageController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Mesajınız',
                  labelStyle: TextStyle(color: accentColor.withOpacity(0.7)),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 16,
                minLines: 12,
                keyboardType: TextInputType.multiline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen mesajınızı girin.';
                  }
                  if (value.length < 10) {
                    return 'Mesajınız en az 10 karakter olmalıdır.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: FontWidget(
            text: 'İptal',
            styleType: TextStyleType.labelLarge,
            color: accentColor,
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _sendSupportEmail,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : FontWidget(
                  text: 'Gönder',
                  styleType: TextStyleType.labelLarge,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
        ),
      ],
    );
  }
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
        'question': 'MOVLİQ NEDİR?',
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
        'question': 'NEDEN ADIMLARIM VE KONUMUM UYGULAMADA ÇALIŞMIYOR?',
        'answer':
            '''Bunun sebebi büyük ihtimalle adım ve konum izinlerinin kapalı olmasıdır.
Yarışlar, Solo Mod ve diğer özelliklerin düzgün çalışması için bu iki izne ihtiyaç duyuyoruz.

📲 Çözüm için:

Telefon ayarlarına git

Uygulamalar > Movliq'i seç

“Adım (hareket)” ve “Konum” izinlerini aç

İzinleri açtıktan sonra uygulamayı yeniden başlat ve tekrar dene.
Hâlâ sorun yaşıyorsan bizimle iletişime geçebilirsin! 🛠️''',
        'isExpanded': true,
      },
      {
        'question': 'Canlı Yarış Nasıl Çalışır?',
        'answer':
            '''Kullanıcı, uygulama üzerinden canlı yarış lobisine katılırken yarışın türünü (iç veya dış mekân) ve süresini seçer. Sistem, aynı yarış ayarlarına sahip diğer kullanıcılarla eşleştirme yapar veya kullanıcı yeni bir yarış başlatarak oda oluşturabilir.
Tüm yarışmacılar belirlenen saatte veya “başlat” komutuyla aynı anda yarışa başlar.

Yarış sonucunda;

🥇 1. olan: Aldığı toplam mesafe × 3

🥈 2. olan: Aldığı toplam mesafe × 2

🥉 3. olan: Aldığı toplam mesafe × 1.5
kadar mCoin kazanır.

Diğer sıralamalardaki katılımcılar da aldıkları toplam mesafe kadar mCoin kazanır.
Yani sonuncu olsan bile üzülme — yine de coin kazanırsın! 🏆''',
        'isExpanded': true,
      },
      {
        'question': 'Solo Mod',
        'answer': '''Zaman sınırlaması olmadan kendi ritmini yakala!
İster yürüyüş, ister koşu — Solo Mod tam sana göre!

🕒 Dilediğin an başla, istediğin zaman dur

📡 Adım, hız ve mesafe verilerin anlık takip edilir

🗺️ Nerede olursan ol, performansını sergile

🧠 Kişisel hedeflerine ulaşırken ilerlemeni kaydet

🎯 Kayıt edilen her aktiviteyle mCoin kazanırsın.
Ama unutma:
💡 Solo Mod'da kazandığın mCoin, canlı yarışlara göre biraz daha azdır.
Yine de her adımın ödül!

🟢 Solo mod = özgürlük, esneklik ve motivasyon!''',
        'isExpanded': true,
      },
      {
        'question': 'Sadece Uygulama DEĞİL, BİR KÜLTÜR',
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
        'question': 'ÖDÜL SİSTEMİ & mCOİN',
        'answer':
            '''Ne kadar çok hareket edersen, o kadar çok kazanırsın! mCoin, movliq evreninde hareketin karşılığıdır. Attığın her adım, çıktığın her yarış, gösterdiğin her performans sana mCoin olarak geri döner.
Kazandığın mCoin\'leri Movliq mağazasında; kuponlara, özel kampanyalara, sürpriz hediyelere ve daha fazlasına dönüştürebilirsin.
Nasıl Kazanırsın?
• Canlı yarışlara katıl
• Solo modda aktif ol
• Günlük,haftalık,aylık hedefleri tamamla
• Özel görevlerde başarı göster
• Ortak havuz yarışlarında birinci ol''',
        'isExpanded': true,
      },
      {
        'question': 'BİREYSEL & SOSYAL DENEYİM',
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
        'question': 'ORTAK HAVUZ YARISLARI',
        'answer':
            '''Arkadaşlarınla heyecanı artırmak istiyorsan doğru yerdesin! Movliq\'te özel odalarda "ortak havuz yarışları" oluşturabilirsin.

🧩 Odayı kuran kişi, yarış için bir mCoin miktarı belirler.
👥 Katılmak isteyen arkadaşlar, belirlenen mCoin miktarına sahipse yarışa dahil olabilir.
🏁 Yarış sonunda birinci olan kişi, o odada toplanan tüm mCoinleri kazanır!

Hazırlığını iyi yap — çünkü bu yarışta ödül büyük!
mCoin\'lerini kaptırmamak için elinden geleni yap! 😉🏃‍♂️''',
        'isExpanded': true,
      },
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: FontWidget(
          text: 'Yardım & Destek',
          styleType: TextStyleType.titleLarge,
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
              text:
                  'Sorularınız mı var? Size yardımcı olmaktan mutluluk duyarız.',
              styleType: TextStyleType.labelLarge,
              color: secondaryTextColor,
              fontSize: 15,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Bize Ulaşın', textColor), // Pass color
            ElevatedButton.icon(
              onPressed: () => _launchEmail(
                  context, ref), // Updated to call with context and ref
              icon:
                  Icon(Icons.email_outlined, color: backgroundColor, size: 20),
              label: FontWidget(
                text: 'E-posta Gönder',
                styleType: TextStyleType.labelLarge,
                fontWeight: FontWeight.bold,
                color: backgroundColor,
              ),
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
              child: FontWidget(
                text: 'Destek taleplerinize en kısa sürede yanıt vereceğiz.',
                styleType: TextStyleType.labelLarge,
                color: labelColor,
                fontSize: 13,
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
      child: FontWidget(
        text: title,
        styleType: TextStyleType.labelLarge,
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
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
        title: FontWidget(
          text: question,
          styleType: TextStyleType.titleMedium,
          color: textColor,
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
        title: FontWidget(
          text: question,
          styleType: TextStyleType.titleMedium,
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0)
                .copyWith(top: 0),
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: <Widget>[
          FontWidget(
            text: answer,
            styleType: TextStyleType.bodyLarge,
            color: secondaryTextColor,
            fontSize: 14,
          ),
        ],
      ),
    );
  }
}
