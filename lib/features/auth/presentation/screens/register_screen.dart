import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_provider.dart';
import 'welcome_screen.dart';
import 'package:flutter/services.dart';
import 'login_input_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword1 = true;
  bool _obscurePassword2 = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7BB027);
    const Color textFieldBackgroundColor = Color(0xFF333333);
    const Color hintTextColor = Color(0xFFBDBDBD);
    const Color textColor = Colors.white;
    const Color buttonColor = Color(0xFFC4FF62);

    ref.listen(authProvider, (previous, next) {
      next.whenOrNull(
        loading: () {},
        error: (error, _) {
          if (mounted) {
            String errorMessage = 'Bir hata oluştu';
            if (error is Map<String, dynamic> && error['message'] != null) {
              errorMessage = error['message'];
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        data: (token) {
          if (token != null) {
            print('Registration successful! Token: $token');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const WelcomeScreen(),
              ),
            );
          } else {
            print("register failed");
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: primaryColor,
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
                  const SizedBox(height: 10),
                  Text(
                    'Yeni Hesap Oluştur',
                    style: GoogleFonts.bangers(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/images/registerpicture.png',
                    height: 250,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    style: GoogleFonts.bangers(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(195, 0, 0, 0),
                      hintText: 'E-posta Adresi',
                      hintStyle: GoogleFonts.bangers(
                          color: hintTextColor, fontSize: 16),
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
                      fontWeight: FontWeight.bold,
                    ),
                    obscureText: _obscurePassword1,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(195, 0, 0, 0),
                      hintText: 'Parola Oluştur',
                      hintStyle: GoogleFonts.bangers(
                          color: hintTextColor, fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword1
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: hintTextColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword1 = !_obscurePassword1;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Lütfen bir parola oluşturun';
                      }
                      if (value!.length < 8) {
                        return 'Parola en az 8 karakter olmalı';
                      }
                      if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                        return 'Parola en az bir büyük harf içermeli';
                      }
                      if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                        return 'Parola en az bir küçük harf içermeli';
                      }
                      if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
                        return 'Parola en az bir rakam içermeli';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ' Parola en az 8 karakter, büyük harf, küçük harf ve rakam içermelidir.',
                    style: GoogleFonts.bangers(
                        color: const Color.fromARGB(141, 255, 255, 255),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    style: GoogleFonts.bangers(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    obscureText: _obscurePassword2,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(195, 0, 0, 0),
                      hintText: 'Parolayı Tekrarla',
                      hintStyle: GoogleFonts.bangers(
                          color: hintTextColor, fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword2
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: hintTextColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword2 = !_obscurePassword2;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Lütfen parolanızı tekrar girin';
                      }
                      if (value != _passwordController.text) {
                        return 'Parolalar eşleşmiyor';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.bangers(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        ref.read(authProvider.notifier).register(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                            );
                      }
                    },
                    child: Text('Hesabımı Oluştur',
                        style: GoogleFonts.bangers(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Zaten bir hesabın var mı? ',
                        style: GoogleFonts.bangers(
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginInputScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Giriş Yap',
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
