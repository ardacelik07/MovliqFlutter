import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/config/api_config.dart';
import 'verify_code_screen.dart'; // Sonraki ekran
// import '../widgets/background_widget.dart'; // Arka plan widget'ı (KALDIRILDI)
// import '../widgets/custom_snackbar.dart'; // Özel Snackbar (Henüz yok
import '../widgets/font_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.requestPasswordResetEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // API success kodları
        if (mounted) {
          // Yönlendirmeyi etkinleştir
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VerifyCodeScreen(email: _emailController.text.trim()),
            ),
          );
          // Opsiyonel: Başarı mesajı gösterilebilir
          // showSuccessSnackbar(context, 'Doğrulama kodu e-posta adresinize gönderildi.');
        }
      } else {
        // API'den gelen hata mesajını göstermeye çalış
        String errorMessage = 'Kod gönderilirken bir hata oluştu.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // JSON parse hatası olursa varsayılan mesajı kullan
        }
        if (mounted) {
          // TODO: Hata Snackbar'ını etkinleştir (custom_snackbar oluşturulunca)
          // showErrorSnackbar(context, errorMessage);
          print('API Hatası: $errorMessage'); // Geçici print
        }
      }
    } catch (e) {
      if (mounted) {
        // TODO: Hata Snackbar'ını etkinleştir
        // showErrorSnackbar(context, 'Bir ağ hatası oluştu: ${e.toString()}');
        print('Ağ Hatası: ${e.toString()}'); // Geçici print
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stil renkleri (LoginScreen veya NameScreen'den alınabilir)
    const Color primaryColor = Color(0xFF7BB027);
    const Color textFieldBgColor = Color.fromARGB(195, 0, 0, 0);
    const Color labelColor = Color.fromARGB(255, 222, 222, 222);
    const Color inputColor = Colors.white;
    const Color buttonBgColor = Color(0xFFC4FF62); // Yeşil buton
    const Color buttonTextColor = Colors.black;

    return Scaffold(
      backgroundColor: primaryColor,
      extendBodyBehindAppBar: true, // Arka planın AppBar arkasına geçmesi için
      appBar: AppBar(
        title: FontWidget(
          text: 'Şifremi Unuttum',
          styleType: TextStyleType.titleLarge,
          color: Colors.white,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            const IconThemeData(color: Colors.white), // Geri butonu rengi
      ),
      body: Stack(
        children: [
          // Gradient Arka Plan (LoginInputScreen'den alındı)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
                  primaryColor, // Stil renklerinden alındı
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        height: MediaQuery.of(context).size.height *
                            0.1), // Üst boşluk
                    // Dummy Illustration replaced with actual image
                    Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: Image.asset(
                        'assets/images/sifremiunuttum1.png',
                        fit: BoxFit
                            .contain, // Or BoxFit.cover based on preference
                      ), // Use the same image as login
                    ),
                    const SizedBox(height: 60),
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      style: GoogleFonts.boogaloo(
                        color: inputColor,
                        fontSize: 16,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'E-posta Adresi',
                        hintStyle: GoogleFonts.boogaloo(
                          color: labelColor,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: textFieldBgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Lütfen e-posta adresinizi girin';
                        }
                        // Basit e-posta format kontrolü
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                          return 'Geçerli bir e-posta adresi girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    // Send Code Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBgColor,
                        foregroundColor: buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.bangers(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isLoading ? null : _requestPasswordReset,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: buttonTextColor,
                                strokeWidth: 3,
                              ),
                            )
                          : FontWidget(
                              text: 'Kod Gönder',
                              styleType: TextStyleType.bodyLarge,
                              fontWeight: FontWeight.bold,
                              color: buttonTextColor,
                            ),
                    ),

                    const SizedBox(height: 40), // Alt boşluk
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
