import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/config/api_config.dart';
import 'login_input_screen.dart'; // Başarılı olunca Login'e dön
// import '../widgets/background_widget.dart'; // KALDIRILDI
// import '../widgets/custom_snackbar.dart'; // Henüz yok

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email; // Önceki ekrandan gelen email

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPasswordVerifiedEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': widget.email,
          'newPassword': _passwordController
              .text, // API body'sine göre sadece yeni şifre yeterli
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Başarı mesajı göster ve Login ekranına yönlendir
          // TODO: Başarı Snackbar'ını etkinleştir
          /*
            showSuccessSnackbar(
              context,
              'Şifreniz başarıyla güncellendi. Lütfen yeni şifrenizle giriş yapın.',
              duration: const Duration(seconds: 3),
            );
            */
          print('Başarılı! Şifre sıfırlandı. Login ekranına yönlendiriliyor.');

          // Şifre sıfırlama ekranlarını stack'ten temizleyerek login'e git
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginInputScreen()),
            (Route<dynamic> route) => false, // Tüm önceki route'ları kaldır
          );
        }
      } else {
        String errorMessage = 'Şifre sıfırlanırken bir hata oluştu.';
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
    const Color primaryColor = Color(0xFF7BB027);
    const Color buttonTextColor = Colors.black;
    const Color iconColor = Colors.grey;

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
                        'assets/images/sifremiunuttum3.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // New Password Field
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: inputColor),
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Yeni Parolanızı Giriniz',
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Lütfen yeni şifrenizi girin';
                        }
                        if (value!.length < 6) {
                          return 'Şifre en az 6 karakter olmalıdır';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Confirm New Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: inputColor),
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Yeni Parolanızı Tekrar Giriniz',
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Lütfen yeni şifrenizi tekrar girin';
                        }
                        if (value != _passwordController.text) {
                          return 'Şifreler eşleşmiyor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    // Create Password Button
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
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: buttonTextColor,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Parola Oluştur'),
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
