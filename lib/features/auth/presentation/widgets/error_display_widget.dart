import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final Object errorObject;

  const ErrorDisplayWidget({
    super.key,
    required this.errorObject,
  });

  String _parseErrorMessage(Object error) {
    if (error is Map<String, dynamic> && error['message'] != null) {
      return error['message'].toString();
    } else if (error is String) {
      return error;
    }
    return 'Bir hata oluştu';
  }

  @override
  Widget build(BuildContext context) {
    final String displayMessage = _parseErrorMessage(errorObject);
    return SelectableText.rich(
      TextSpan(
        text: displayMessage,
        style: GoogleFonts.bangers(
          color: Colors.redAccent,
          fontSize: 14,
        ),
      ),
      textAlign: TextAlign.center,
    );
  }
}
