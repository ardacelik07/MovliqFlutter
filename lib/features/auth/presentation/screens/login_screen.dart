import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/background_widget.dart';
import '../widgets/social_login_button.dart';
import '../widgets/tagline_widget.dart';
import '../widgets/footer_widget.dart';
import '../screens/register_screen.dart';
import '../screens/login_input_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/font_widget.dart';
import '../widgets/privacy_policy_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isPolicyAcceptedByCheckbox = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _setHasAcceptedPolicyOverall(bool accepted) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasAcceptedPolicyOverall', accepted);
    if (mounted && accepted) {
      setState(() {
        _isPolicyAcceptedByCheckbox = true;
      });
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return PrivacyPolicyWidget(
          onAccepted: () async {
            await _setHasAcceptedPolicyOverall(true);
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7BB027);
    const Color lightGreenButton = Color(0xFFC4FF62);
    const Color socialButtonBg = Color.fromARGB(150, 255, 255, 255);
    const Color socialButtonFg = Colors.black87;
    const Color emailButtonBg = lightGreenButton;
    const Color emailButtonFg = Colors.black;
    const Color textColor = Colors.white;
    const Color secondaryTextColor = Colors.white70;
    const Color footerLinkColor = Colors.white;

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundWidget(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/movliq_withtext.png',
                      height: 100,
                    ),
                    const SizedBox(height: 60),
                    FontWidget(
                      text: 'Daha Çok Hareket,',
                      styleType: TextStyleType.titleLarge,
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.start,
                    ),
                    FontWidget(
                      text: 'Daha Çok Kazanç',
                      styleType: TextStyleType.titleLarge,
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 48),
                    FontWidget(
                      text:
                          'Movliq’te ödüller, fırsatlar ve eğlence; hepsi seni bir adım uzaklıkta bekliyor!',
                      styleType: TextStyleType.bodyMedium,
                      color: secondaryTextColor,
                      fontSize: 18,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 180),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emailButtonBg,
                          foregroundColor: emailButtonFg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledForegroundColor:
                              emailButtonFg.withOpacity(0.5),
                          disabledBackgroundColor:
                              emailButtonBg.withOpacity(0.5),
                        ),
                        onPressed: _isPolicyAcceptedByCheckbox
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const LoginInputScreen(),
                                  ),
                                );
                              }
                            : null,
                        child: FontWidget(
                            text: 'E-posta İle Devam Et',
                            styleType: TextStyleType.bodyLarge,
                            color: _isPolicyAcceptedByCheckbox
                                ? emailButtonFg
                                : emailButtonFg.withOpacity(0.7),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: textColor,
                            ),
                            child: Checkbox(
                              value: _isPolicyAcceptedByCheckbox,
                              onChanged: (bool? value) {
                                setState(() {
                                  _isPolicyAcceptedByCheckbox = value ?? false;
                                });
                              },
                              activeColor: lightGreenButton,
                              checkColor: Colors.black,
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style:
                                    TextStyle(color: textColor, fontSize: 13),
                                children: [
                                  const TextSpan(
                                      text:
                                          'Gizlilik Politikasını okudum ve kabul ediyorum. '),
                                  TextSpan(
                                    text: '[ Gizlilik Politikasını Gör]',
                                    style: TextStyle(
                                      color: lightGreenButton,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        _showPrivacyPolicyDialog();
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            unselectedWidgetColor: textColor,
                          ),
                          child: Checkbox(
                            value: _isPolicyAcceptedByCheckbox,
                            onChanged: (bool? value) {
                              setState(() {
                                _isPolicyAcceptedByCheckbox = value ?? false;
                              });
                            },
                            activeColor: lightGreenButton,
                            checkColor: Colors.black,
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: textColor, fontSize: 13),
                              children: [
                                const TextSpan(
                                    text:
                                        'Gizlilik Politikasını okudum ve kabul ediyorum. '),
                                TextSpan(
                                  text: '[ Gizlilik Politikasını Gör]',
                                  style: TextStyle(
                                    color: lightGreenButton,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _showPrivacyPolicyDialog();
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    required Color bgColor,
    required Color fgColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: FaIcon(icon, size: 20, color: fgColor),
        label: FontWidget(
            text: text,
            styleType: TextStyleType.bodyMedium,
            color: fgColor,
            fontWeight: FontWeight.w500),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
