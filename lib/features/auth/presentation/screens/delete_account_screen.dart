import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:my_flutter_project/core/config/api_config.dart';
import 'package:my_flutter_project/core/services/storage_service.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/user_data_provider.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/font_widget.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/login_screen.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/error_display_widget.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final userData = ref.read(userDataProvider).value;
      final userId = userData?.id;

      if (userId == null) {
        throw Exception('User ID not found.');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/User/delete/$userId');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await StorageService.deleteToken();
        ref.invalidate(userDataProvider);
        // Add invalidation for other relevant providers if necessary e.g. userProfileProvider
        // ref.invalidate(userProfileProvider);

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: FontWidget(
              text: 'Hesabınız başarıyla silindi.',
              styleType: TextStyleType.bodyMedium,
              color: Colors.black,
            ),
            backgroundColor: const Color(0xFFC4FF62),
          ),
        );
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        String errorMessage = 'Hesap silinemedi.';
        try {
          final responseBody = jsonDecode(response.body);
          errorMessage =
              responseBody['message'] ?? responseBody['error'] ?? errorMessage;
        } catch (_) {
          // Use default error message or response.body if not JSON
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color primaryColor = const Color(0xFF000000); // Black background
    final Color accentColor = const Color(0xFFC4FF62); // Accent green
    final Color textColor = Colors.white;
    final Color destructiveColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: FontWidget(
          text: 'Hesabı Sİl',
          styleType: TextStyleType.titleMedium,
          color: textColor,
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: destructiveColor,
              size: 80,
            ),
            const SizedBox(height: 24),
            FontWidget(
              text: 'Hesabınızı sİlmek İstedİğİnİzden emİn mİsİnİz?',
              styleType: TextStyleType.titleMedium,
              color: textColor,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FontWidget(
              text:
                  'Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinecektir. Bu, profilinizi, etkinlik geçmişinizi ve kazandığınız mCoin veya ödülleri içerir.',
              styleType: TextStyleType.bodyMedium,
              color: textColor.withOpacity(0.7),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: destructiveColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _deleteAccount,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : FontWidget(
                      text: 'Hesabımı Kalıcı Olarak Sil',
                      styleType: TextStyleType.labelLarge,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: FontWidget(
                text: 'İptal',
                styleType: TextStyleType.labelLarge,
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
