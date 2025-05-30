import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/tabs.dart';
import 'package:flutter/services.dart';
import '../providers/user_data_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginInputScreen extends ConsumerStatefulWidget {
  const LoginInputScreen({super.key});

  @override
  ConsumerState<LoginInputScreen> createState() => _LoginInputScreenState();
}

class _LoginInputScreenState extends ConsumerState<LoginInputScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // iOS izinlerini isteyecek metod

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      next.whenOrNull(
        loading: () {},
        error: (error, _) {
          if (mounted) {
            String errorMessage = 'Bir hata oluştu'; // Varsayılan mesaj
            if (error is Map<String, dynamic> && error['message'] != null) {
              // Map ve message anahtarı varsa, message'ı kullan
              if (error['message'] is String) {
                errorMessage = error['message'] as String;
              } else {
                // message alanı String değilse, güvenli bir şekilde string'e çevir
                errorMessage = error['message'].toString();
              }
            } else if (error is String) {
              // Hata doğrudan bir String ise (eski durum veya başka bir senaryo)
              errorMessage = error;
            } else {
              // Diğer hata türleri için genel bir mesaj veya error.toString()
              errorMessage = error.toString();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$errorMessage'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        data: (token) {
          // Check if the screen is still mounted AND is the current route
          if (mounted &&
              ModalRoute.of(context)?.isCurrent == true &&
              token != null) {
            print('Login successful! Token: $token');

            // Kullanıcı verilerini getir
            ref.read(userDataProvider.notifier).fetchUserData();
            ref.read(userDataProvider.notifier).fetchCoins();
            ref.read(selectedTabProvider.notifier).state = 0;

            // TabsScreen'e yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TabsScreen(),
              ),
            );
          } else if (token != null &&
              (ModalRoute.of(context)?.isCurrent == false)) {
            // Optional: Log that the listener fired but didn't act because screen wasn't current
            print(
                'LoginInputScreen: authProvider updated but screen is not current (e.g., during registration flow). Token: $token');
          }
        },
      );
    });

    const Color primaryColor = Color(0xFF7BB027);
    const Color hintTextColor = Color(0xFFBDBDBD);
    const Color textColor = Colors.white;
    const Color buttonColor = Color(0xFFC4FF62);

    return Scaffold(
      backgroundColor: primaryColor,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
              primaryColor
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Tekrar aramızda olmana sevindik',
                    style: GoogleFonts.bangers(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 40),
                  Image.asset(
                    'assets/images/loginpicture.png',
                    height: 250,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    style: GoogleFonts.bangers(
                      color: textColor,
                      fontSize: 16,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(195, 0, 0, 0),
                      hintText: 'E-posta Adresİ',
                      hintStyle: GoogleFonts.bangers(
                        color: hintTextColor,
                        fontSize: 16,
                      ),
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
                      if (!value!.contains('@') || !value.contains('.')) {
                        return 'Lütfen geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    style: GoogleFonts.bangers(
                      color: textColor,
                      fontSize: 16,
                    ),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(195, 0, 0, 0),
                      hintText: 'Parolanız',
                      hintStyle: GoogleFonts.bangers(
                        color: hintTextColor,
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: hintTextColor,
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
                        return 'Lütfen parolanızı girin';
                      }
                      if (value!.length < 6) {
                        return 'Parola en az 6 karakter olmalı';
                      }
                      /*if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                        return 'Parola en az bir büyük harf içermeli';
                      }
                      if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                        return 'Parola en az bir küçük harf içermeli';
                      }
                      if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
                        return 'Parola en az bir rakam içermeli';
                      }*/
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen()),
                        );
                      },
                      child: Text(
                        'Şifremi unuttum?',
                        style: GoogleFonts.bangers(
                          color: buttonColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.bangers(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        ref.read(authProvider.notifier).login(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                            );
                      }
                    },
                    child: Text('Gİrİş Yap',
                        style: GoogleFonts.bangers(
                          fontSize: 16,
                        )),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hesabın yok mu? ',
                        style: GoogleFonts.bangers(
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegisterScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Kayıt Ol',
                          style: GoogleFonts.bangers(
                            color: buttonColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
