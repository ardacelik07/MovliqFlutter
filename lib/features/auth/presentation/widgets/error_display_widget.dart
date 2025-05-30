import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Projenizdeki fontu kullanın

class ErrorDisplayWidget extends StatelessWidget {
  final String message;

  const ErrorDisplayWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        text: message,
        style: GoogleFonts.bangers(
          // Font stilinizi buraya uyarlayın
          color: Colors.redAccent,
          fontSize: 14,
        ),
      ),
      textAlign: TextAlign.center,
    );
  }
}

class AdvancedErrorDisplayWidget extends StatelessWidget {
  final Object errorObject;

  const AdvancedErrorDisplayWidget({
    super.key,
    required this.errorObject,
  });

  String _parseErrorMessage(Object error) {
    if (error is Map<String, dynamic> && error['message'] != null) {
      if (error['message'] is String) {
        return error['message'] as String;
      } else {
        return error['message'].toString();
      }
    } else if (error is String) {
      return error;
    } else if (error.toString().contains('{"statusCode"') &&
        error.toString().contains('"message":')) {
      try {
        final match = RegExp(r"message['\']\s*:\s*['\']([^'\']+)['\']")
            .firstMatch(error.toString());
        if (match != null && match.groupCount >= 1 && match.group(1) != null) {
          return match.group(1)!;
        }
      } catch (_) {
        // Hata olursa varsayılana dön
      }
      String fullError = error.toString();
      return 'Beklenmedik bir hata oluştu: ${fullError.substring(0, (fullError.length > 100) ? 100 : fullError.length)}...';
    }
    String fullError = error.toString();
    return 'Bir hata oluştu: ${fullError.substring(0, (fullError.length > 100) ? 100 : fullError.length)}...';
  }

  @override
  Widget build(BuildContext context) {
    final String displayMessage = _parseErrorMessage(errorObject);
    return SelectableText.rich(
      TextSpan(
        text: displayMessage,
        style: GoogleFonts.bangers(
          // Font stilinizi buraya uyarlayın
          color: Colors.redAccent,
          fontSize: 14,
        ),
      ),
      textAlign: TextAlign.center,
    );
  }
}
