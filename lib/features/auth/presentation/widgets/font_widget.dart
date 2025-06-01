import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Enum to define different text style types
enum TextStyleType {
  titleLarge, // For main titles
  titleMedium, // For subtitles or section titles
  titleSmall, // For smaller titles
  bodyLarge, // For primary body text
  bodyMedium, // For secondary body text
  bodySmall, // For captions or fine print
  labelLarge, // For buttons or important labels
  labelMedium, // For medium emphasis labels
  labelSmall, // For low emphasis labels
}

class FontWidget extends StatelessWidget {
  final String text;
  final TextStyleType styleType;
  final Color? color;
  final TextAlign? textAlign;
  final FontWeight? fontWeight; // Allow overriding fontWeight
  final double? fontSize; // Allow overriding fontSize
  final TextOverflow? overflow;
  final int? maxLines;

  const FontWidget({
    super.key,
    required this.text,
    required this.styleType,
    this.color,
    this.textAlign,
    this.fontWeight,
    this.fontSize,
    this.overflow,
    this.maxLines,
  });

  TextStyle _getTextStyle(BuildContext context) {
    // Default color if not provided
    final textColor =
        this.color ?? Colors.white; // Default to white if no color is passed

    switch (styleType) {
      case TextStyleType.titleLarge:
        return GoogleFonts.bangers(
          fontSize: fontSize ?? 32,
          fontWeight: fontWeight ?? FontWeight.bold,
          color: textColor,
        );
      case TextStyleType.titleMedium:
        return GoogleFonts.bangers(
          fontSize: fontSize ?? 24,
          fontWeight: fontWeight ?? FontWeight.bold,
          color: textColor,
        );
      case TextStyleType.titleSmall:
        return GoogleFonts.bangers(
          fontSize: fontSize ?? 20,
          fontWeight: fontWeight ?? FontWeight.w600,
          color: textColor,
        );
      case TextStyleType.bodyLarge:
        return GoogleFonts.pangolin(
          fontSize: fontSize ?? 16,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: textColor,
        );
      case TextStyleType.bodyMedium:
        return GoogleFonts.pangolin(
          fontSize: fontSize ?? 14,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: textColor,
        );
      case TextStyleType.bodySmall:
        return GoogleFonts.pangolin(
          fontSize: fontSize ?? 12,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: textColor,
        );
      case TextStyleType.labelLarge:
        return GoogleFonts.caveatBrush(
          fontSize: fontSize ?? 16,
          fontWeight: fontWeight ?? FontWeight.bold,
          color: textColor,
        );
      case TextStyleType.labelMedium:
        return GoogleFonts.caveatBrush(
          fontSize: fontSize ?? 14,
          fontWeight:
              fontWeight ?? FontWeight.w500, // Medium weight for poppins labels
          color: textColor,
        );
      case TextStyleType.labelSmall:
        return GoogleFonts.boogaloo(
          fontSize: fontSize ?? 12,
          fontWeight:
              fontWeight ?? FontWeight.w500, // Medium weight for poppins labels
          color: textColor,
        );
      default:
        return GoogleFonts.boogaloo(
          fontSize: fontSize ?? 14,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: textColor,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _getTextStyle(context),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

// Example Usage:
// FontWidget(text: 'Merhaba Dünya', styleType: TextStyleType.titleLarge)
// FontWidget(text: 'Bu bir örnektir.', styleType: TextStyleType.bodyMedium, color: Colors.blue)
// FontWidget(text: 'Küçük Başlık', styleType: TextStyleType.titleSmall, fontWeight: FontWeight.w500)
