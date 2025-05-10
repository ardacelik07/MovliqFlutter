// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      aboutProduct: json['aboutProduct'] as String? ?? '',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      stock: (json['stock'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isVirtual: json['isVirtual'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: Product._dateTimeFromJson(json['createdAt']),
      creatorUserId: (json['creatorUserId'] as num?)?.toInt(),
      expirationDate: Product._dateTimeFromJson(json['expirationDate']),
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'aboutProduct': instance.aboutProduct,
      'brand': instance.brand,
      'model': instance.model,
      'stock': instance.stock,
      'price': instance.price,
      'isVirtual': instance.isVirtual,
      'isActive': instance.isActive,
      'createdAt': Product._dateTimeToJson(instance.createdAt),
      'creatorUserId': instance.creatorUserId,
      'expirationDate': Product._dateTimeToJson(instance.expirationDate),
      'photos': instance.photos?.map((e) => e.toJson()).toList(),
    };
