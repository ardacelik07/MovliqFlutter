import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/config/api_config.dart'; // API yapılandırmasını import et
// Provider importları (varsayılan)
import '../providers/auth_provider.dart';
import '../providers/user_data_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  // --- Theme Colors (Match UpdateUserInfoScreen) ---
  final Color _backgroundColor = Colors.black;
  final Color _cardColor = Colors.grey[900]!;
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.grey[400]!;
  final Color _accentColor = const Color(0xFFB2FF59); // Light green accent
  final Color _labelColor = Colors.grey[500]!;
  final Color _errorColor = Colors.redAccent;

  @override
  void dispose() {
    _currentPasswordController
        .dispose(); // Bu controller artık API isteği için kullanılmayacak ama UI'da kalabilir
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    // Client-side validation
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen tüm alanları doldurun.';
        _isLoading = false;
      });
      return;
    }
    if (newPassword.length < 8) {
      setState(() {
        _errorMessage = 'Yeni şifre en az 8 karakter olmalıdır.';
        _isLoading = false;
      });
      return;
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(newPassword)) {
      setState(() {
        _errorMessage = 'Yeni şifre en az bir büyük harf içermelidir.';
        _isLoading = false;
      });
      return;
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(newPassword)) {
      setState(() {
        _errorMessage = 'Yeni şifre en az bir küçük harf içermelidir.';
        _isLoading = false;
      });
      return;
    }
    if (!RegExp(r'(?=.*[0-9])').hasMatch(newPassword)) {
      setState(() {
        _errorMessage = 'Yeni şifre en az bir rakam içermelidir.';
        _isLoading = false;
      });
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Şifreler eşleşmiyor';
        _isLoading = false;
      });
      return;
    }

    // --- Get User Email and Auth Token --- // Email artık gerekli
    final userState = ref.read(userDataProvider);
    final authState = ref.read(authProvider);

    final String? userEmail = userState.value?.email;
    final String? token = authState.value;

    if (userEmail == null || userEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Kullanıcı e-postası alınamadı.';
        _isLoading = false;
      });
      return;
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage =
            'Yetkilendirme anahtarı bulunamadı. Lütfen tekrar giriş yapın.';
        _isLoading = false;
      });
      return;
    }

    // --- API Call Logic ---
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse(ApiConfig.changePasswordEndpoint),
        headers: headers,
        body: jsonEncode({
          'email': userEmail,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Şifre başarıyla değiştirildi!',
                  style: TextStyle(color: _backgroundColor)),
              backgroundColor: _accentColor,
            ),
          );
          Navigator.pop(context);
        } else {
          String errorMsg = 'Şifre değiştirilirken bir hata oluştu.';
          try {
            final responseBody = jsonDecode(response.body);
            print('API Error Response: ${response.body}');
            if (responseBody is Map && responseBody.containsKey('message')) {
              errorMsg = responseBody['message'];
            } else if (responseBody is Map &&
                responseBody.containsKey('detail')) {
              errorMsg = responseBody['detail'];
            } else if (response.statusCode == 400) {
              // 400 hatası için özel mesaj (Mevcut şifre hatası olabilir)
              errorMsg =
                  'Mevcut şifreniz hatalı veya geçersiz. (${response.statusCode})';
            } else {
              errorMsg =
                  'Sunucu hatası (${response.statusCode}). Lütfen tekrar deneyin.';
            }
          } catch (e) {
            print('Error parsing API error response: $e');
            print('Raw API Error Response: ${response.body}');
            errorMsg = 'Sunucudan geçersiz yanıt alındı.';
          }
          setState(() {
            _errorMessage = errorMsg;
          });
        }
      }
    } catch (e) {
      print('Network or other error during password change: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Bağlantı hatası veya beklenmedik bir sorun oluştu.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Şifre Değiştir',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _accentColor),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mevcut Şifre Alanı (UI'da kalabilir, doğrulaması kaldırılabilir)
              _buildPasswordField(
                controller: _currentPasswordController,
                hintText: 'Mevcut şifrenizi girin.', // Kullanıcıya bilgi amaçlı
                obscureText: _obscureCurrentPassword,
                onToggleVisibility: () {
                  setState(
                      () => _obscureCurrentPassword = !_obscureCurrentPassword);
                },
              ),
              const SizedBox(height: 16),
              // Yeni Şifre Alanı
              _buildPasswordField(
                controller: _newPasswordController,
                hintText: 'Yeni şifrenizi girin.',
                obscureText: _obscureNewPassword,
                onToggleVisibility: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
              const SizedBox(height: 16),
              // Yeni Şifre Tekrar Alanı
              _buildPasswordField(
                controller: _confirmPasswordController,
                hintText: 'Yeni şifrenizi tekrar girin.',
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              const SizedBox(height: 24),
              // Şifre Gerekliliği
              _buildPasswordRequirement('Şifreniz şunları içermelidir:',
                  ['8 karakter uzunluğunda, büyük harf, küçük harf, rakam.']),
              const SizedBox(height: 24),
              // Hata Mesajı
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Center(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: _errorColor, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              // Buton
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _backgroundColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: _backgroundColor),
                      )
                    : const Text(
                        'Şifreyi Değiştir',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: _textColor, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: _secondaryTextColor.withOpacity(0.7)),
        filled: true,
        fillColor: _cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _secondaryTextColor,
            size: 20,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String title, List<String> requirements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: _labelColor, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...requirements.map(
          (req) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: _secondaryTextColor, size: 18),
                const SizedBox(width: 8),
                Text(req,
                    style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
