import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

@immutable
class CouponModel {
  final int userPurchaseId;
  final DateTime purchaseDate;
  final int productId;
  final String productName;
  final String? productMainImageUrl; // Assuming it can be null
  final int acquiredCouponId;
  final String acquiredCouponCode;
  final DateTime expirationDate;

  const CouponModel({
    required this.userPurchaseId,
    required this.purchaseDate,
    required this.productId,
    required this.productName,
    this.productMainImageUrl,
    required this.acquiredCouponId,
    required this.acquiredCouponCode,
    required this.expirationDate,
  });

  // Manual factory constructor for JSON deserialization
  factory CouponModel.fromJson(Map<String, dynamic> json) {
    // Helper function to parse date strings safely
    DateTime _parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) {
        print('⚠️ CouponModel: Received null or empty date string.');
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        print(
            'ℹ️ CouponModel: Parsing date string: "$dateString"'); // Log input
        final DateTime parsedDate = DateTime.parse(dateString);
        print(
            '✅ CouponModel: Successfully parsed date: $parsedDate'); // Log success
        return parsedDate;
      } catch (e) {
        print(
            '❌ CouponModel: Error parsing date: "$dateString". Error: $e'); // Log error
        // Fallback or throw a more specific error
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return CouponModel(
      userPurchaseId:
          json['userPurchaseId'] as int? ?? 0, // Provide default or handle null
      purchaseDate: _parseDate(json['purchaseDate'] as String?),
      productId: json['productId'] as int? ?? 0,
      productName: json['productName'] as String? ?? 'N/A', // Provide default
      productMainImageUrl: json['productMainImageUrl'] as String?,
      acquiredCouponId: json['acquiredCouponId'] as int? ?? 0,
      acquiredCouponCode: json['acquiredCouponCode'] as String? ?? 'N/A',
      expirationDate: _parseDate(json['expirationDate'] as String?),
    );
  }

  // Manual method for JSON serialization (if needed)
  Map<String, dynamic> toJson() => {
        'userPurchaseId': userPurchaseId,
        'purchaseDate': purchaseDate.toIso8601String(),
        'productId': productId,
        'productName': productName,
        'productMainImageUrl': productMainImageUrl,
        'acquiredCouponId': acquiredCouponId,
        'acquiredCouponCode': acquiredCouponCode,
        'expirationDate': expirationDate.toIso8601String(),
      };

  // Example of a formatted date getter for the UI
  String get formattedPurchaseDate {
    try {
      // Using 'tr_TR' locale for Turkish month names if needed, ensure intl is initialized
      // Or use default locale
      return DateFormat('d MMMM yyyy', 'tr_TR').format(purchaseDate);
    } catch (e) {
      return 'Invalid Date'; // Handle formatting errors
    }
  }

  // Example of a formatted expiration date getter for the UI
  String get formattedExpirationDate {
    try {
      // Check if the date is the default epoch value before formatting
      if (expirationDate.millisecondsSinceEpoch == 0) {
        print(
            '⚠️ CouponModel: Attempted to format default/invalid expiration date.');
        return 'Invalid Date';
      }
      // Using 'tr_TR' locale for Turkish month names if needed
      final String formatted =
          DateFormat('d MMMM yyyy', 'tr_TR').format(expirationDate);
      print(
          '✅ CouponModel: Formatted expiration date $expirationDate to $formatted'); // Log success
      return formatted;
    } catch (e) {
      print(
          '❌ CouponModel: Error formatting expiration date: $expirationDate. Error: $e'); // Log error
      return 'Invalid Date'; // Handle formatting errors
    }
  }

  /// Calculates and formats the remaining time until the expiration date.
  String get remainingTimeFormatted {
    final Duration difference = expirationDate.difference(DateTime.now());

    if (difference.isNegative) {
      return 'Süresi Doldu';
    }

    final int days = difference.inDays;
    final int hours = difference.inHours.remainder(24);
    final int minutes = difference.inMinutes.remainder(60);

    final List<String> parts = [];
    if (days > 0) {
      parts.add('$days gün');
    }
    if (hours > 0) {
      parts.add('$hours saat');
    }
    if (minutes > 0) {
      parts.add('$minutes dakika');
    }

    // If less than a minute remaining but not expired
    if (parts.isEmpty && !difference.isNegative) {
      return 'Bir dakikadan az';
    }

    return parts.join(' ');
  }
}
