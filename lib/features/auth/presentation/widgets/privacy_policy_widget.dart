import 'package:flutter/material.dart';
import 'font_widget.dart'; // Assuming FontWidget is in the same directory or accessible

class PrivacyPolicyWidget extends StatefulWidget {
  final VoidCallback onAccepted;

  const PrivacyPolicyWidget({
    super.key,
    required this.onAccepted,
  });

  @override
  State<PrivacyPolicyWidget> createState() => _PrivacyPolicyWidgetState();
}

class _PrivacyPolicyWidgetState extends State<PrivacyPolicyWidget> {
  bool _hasAcceptedPolicy = false;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Colors.black87; // Adjusted for a dialog
    final Color secondaryTextColor = Colors.black54;
    final Color titleColor = Theme.of(context).primaryColor;
    final Color buttonColor = Theme.of(context).primaryColor;
    final Color buttonTextColor = Colors.white;

    return AlertDialog(
      title: FontWidget(
        text: 'Gizlilik Politikası',
        styleType: TextStyleType.titleLarge,
        color: titleColor,
        fontWeight: FontWeight.bold,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FontWidget(
              text: 'Verileriniz bizim için önemli. İşte nasıl koruyoruz:',
              styleType: TextStyleType.bodyMedium,
              color: secondaryTextColor,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            _buildPolicySection(
              title: 'Üçüncü Taraflarla Paylaşım',
              titleColor: titleColor,
              content:
                  'Verileriniz, yalnızca sizin açık rızanızla ve hizmet kalitesini artırmak amacıyla güvenilir üçüncü taraf hizmet sağlayıcılarıyla paylaşılabilir.',
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            CheckboxListTile(
              title: FontWidget(
                text: 'Okudum, anladım ve kabul ediyorum.',
                styleType: TextStyleType.bodyMedium,
                color: textColor,
              ),
              value: _hasAcceptedPolicy,
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    _hasAcceptedPolicy = value;
                  });
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: titleColor,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog without accepting
          },
          child: FontWidget(
            text: 'Reddet',
            styleType: TextStyleType.labelLarge,
            color: secondaryTextColor,
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: buttonTextColor,
          ),
          onPressed: _hasAcceptedPolicy
              ? () {
                  widget.onAccepted();
                  Navigator.of(context).pop(); // Close dialog after accepting
                }
              : null, // Button is disabled if not accepted
          child: FontWidget(
            text: 'Kabul Et',
            styleType: TextStyleType.labelLarge,
            color: buttonTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

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
          styleType: TextStyleType.titleSmall, // Adjusted for dialog
          color: titleColor,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 6),
        FontWidget(
          text: content,
          styleType: TextStyleType.bodySmall, // Adjusted for dialog
          color: secondaryTextColor,
        ),
        if (bulletPoints != null && bulletPoints.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bulletPoints
                  .map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 3.0),
                        child: FontWidget(
                          text: '• $point',
                          styleType: TextStyleType.bodySmall, // Adjusted
                          color: secondaryTextColor,
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
