import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/config/api_config.dart';
import 'reset_password_screen.dart'; // Sonraki ekran
// import '../widgets/background_widget.dart'; // KALDIRILDI
// import '../widgets/custom_snackbar.dart'; // Henüz yok

class VerifyCodeScreen extends ConsumerStatefulWidget {
  final String email; // Önceki ekrandan gelen email

  const VerifyCodeScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyResetCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyResetCodeEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': widget.email,
          'code': _codeController.text.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Yönlendirmeyi etkinleştir
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(email: widget.email),
            ),
          );
        }
      } else {
        String errorMessage = 'Kod doğrulanırken bir hata oluştu.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {}
        if (mounted) {
          // TODO: Hata Snackbar'ını etkinleştir
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
    const Color textFieldBgColor = Color.fromARGB(195, 0, 0, 0);
    const Color labelColor = Color.fromARGB(255, 222, 222, 222);
    const Color inputColor = Colors.white;
    const Color buttonBgColor = Color(0xFFC4FF62);
    const Color buttonTextColor = Colors.black;
    const Color primaryColor = Color(0xFF7BB027);

    return Scaffold(
      backgroundColor: primaryColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Şifremi Unuttum',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Gradient Arka Plan
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
                  const Color(
                      0xFF7BB027), // primaryColor tanımı yok, doğrudan ekledim
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
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    // Dummy Illustration replaced with actual image
                    Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: Image.asset(
                        'assets/images/loginpicture.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Code Field
                    TextFormField(
                      controller: _codeController,
                      style: const TextStyle(color: inputColor),
                      keyboardType:
                          TextInputType.number, // Genellikle kodlar numeriktir
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'E-posta Adresinize Gelen Kodu Giriniz',
                        hintStyle:
                            const TextStyle(color: labelColor, fontSize: 14),
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
                          return 'Lütfen doğrulama kodunu girin';
                        }
                        // Opsiyonel: Kod uzunluğu kontrolü eklenebilir (örn: 6 haneli)
                        /*
                        if (value!.length != 6) {
                          return 'Kod 6 haneli olmalıdır';
                        }
                        */
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    // Verify Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBgColor,
                        foregroundColor: buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isLoading ? null : _verifyResetCode,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: buttonTextColor,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Doğrula'),
                    ),
                    const SizedBox(height: 40),
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
