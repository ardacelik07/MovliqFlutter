import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String category; // Kategori bilgisi için alan
  final List<String> imageUrls; // Resim URL'leri listesi
  final DateTime createdAt;
  final DateTime updatedAt;
  @JsonKey(defaultValue: false)
  final bool isDeleted;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  // Yardımcı getter: İlk resmi almak için
  String get firstImageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';
}
