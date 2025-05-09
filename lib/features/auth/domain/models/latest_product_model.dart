import 'package:flutter/foundation.dart';

@immutable
class LatestProductModel {
  final int id;
  final String name;
  final int price; // API response shows integer price
  final String mainImageUrl;

  const LatestProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.mainImageUrl,
  });

  factory LatestProductModel.fromJson(Map<String, dynamic> json) {
    return LatestProductModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Bilinmeyen Ürün', // Default value
      price: json['price'] as int? ?? 0, // Default value
      mainImageUrl:
          json['mainImageUrl'] as String? ?? '', // Default empty string
    );
  }

  // toJson is not needed if we only fetch data
  // Map<String, dynamic> toJson() => {
  //   'name': name,
  //   'price': price,
  //   'mainImageUrl': mainImageUrl,
  // };
}
