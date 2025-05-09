import 'package:json_annotation/json_annotation.dart';

import 'photo.dart'; // Photo modelini import et

part 'product.g.dart';

@JsonSerializable(
    //fieldRename: FieldRename.snake,
    explicitToJson: true,
    nullable: true) // nullable eklendi
class Product {
  final int? id; // nullable yapıldı
  @JsonKey(defaultValue: '')
  final String name; // defaultValue var, null olamaz
  @JsonKey(defaultValue: '')
  final String description; // defaultValue var, null olamaz
  @JsonKey(defaultValue: '')
  final String category;
  @JsonKey(defaultValue: '')
  final String? aboutProduct; // defaultValue var, null olamaz
  final String? brand; // API'de nullable olabilir
  final String? model; // API'de nullable olabilir
  final int? stock; // API'de nullable olabilir
  @JsonKey(defaultValue: 0.0)
  final double price; // defaultValue eklendi (0.0)
  @JsonKey(defaultValue: false)
  final bool isVirtual;
  @JsonKey(defaultValue: false)
  final bool isActive; // isDeleted yerine isActive kullanalım

  // DateTime'ı düzgün işlemek için özel JsonKey ekleyelim
  @JsonKey(
    defaultValue: null,
    fromJson: _dateTimeFromJson,
    toJson: _dateTimeToJson,
  )
  final DateTime? createdAt; // nullable yapıldı ve özel işleme eklendi

  final int? creatorUserId;
  @JsonKey(
    defaultValue: null,
    fromJson: _dateTimeFromJson,
    toJson: _dateTimeToJson,
  )
  final DateTime? expirationDate; // API'de nullable olabilir
  final List<Photo>? photos; // Nullable yapıldı List<Photo>?
  // final DateTime updatedAt; // API yanıtında updatedAt yok
  // final bool isDeleted; // API yanıtında isDeleted yok, isActive var

  const Product({
    this.id, // nullable olduğu için required kaldırıldı
    required this.name, // defaultValue olduğu için required kalabilir
    required this.description, // defaultValue olduğu için required kalabilir
    required this.category, // defaultValue olduğu için required kalabilir
    this.aboutProduct, // defaultValue olduğu için required kalabilir
    this.brand,
    this.model,
    this.stock,
    required this.price, // defaultValue olduğu için required kalabilir
    required this.isVirtual, // defaultValue olduğu için required kalabilir
    required this.isActive, // defaultValue olduğu için required kalabilir
    this.createdAt, // nullable olduğu için required kaldırıldı
    this.creatorUserId,
    this.expirationDate,
    this.photos, // nullable olduğu için required kaldırıldı
    // required this.updatedAt,
    // required this.isDeleted,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  // DateTime için özel JSON dönüşüm metotları
  static DateTime? _dateTimeFromJson(dynamic json) {
    if (json == null) return null;
    try {
      return DateTime.parse(json.toString());
    } catch (e) {
      print('Error parsing DateTime: $e');
      return null;
    }
  }

  static String? _dateTimeToJson(DateTime? dateTime) {
    return dateTime?.toIso8601String();
  }

  // Yardımcı getter: Ana resmi veya ilk resmi almak için
  String get firstImageUrl {
    // photos null veya boş ise kontrol et
    if (photos == null || photos!.isEmpty) {
      return ''; // Resim yoksa boş string dön
    }
    // isMain true olan ilk resmi bul
    // photos!.firstWhere... olarak erişim (! veya ?.)
    final Photo? mainPhoto = photos!.firstWhere(
      (photo) => photo.isMain,
      orElse: () => photos!.first, // isMain true olan yoksa ilk resmi al
    );
    // Null assertion (!) yerine null-aware (?.) ve null coalescing (??) kullanalım
    return mainPhoto?.url ?? '';
  }
}
