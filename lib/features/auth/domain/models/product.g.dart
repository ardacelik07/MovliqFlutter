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
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      stock: (json['stock'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isVirtual: json['is_virtual'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: Product._dateTimeFromJson(json['created_at']),
      creatorUserId: (json['creator_user_id'] as num?)?.toInt(),
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'brand': instance.brand,
      'model': instance.model,
      'stock': instance.stock,
      'price': instance.price,
      'is_virtual': instance.isVirtual,
      'is_active': instance.isActive,
      'created_at': Product._dateTimeToJson(instance.createdAt),
      'creator_user_id': instance.creatorUserId,
      'photos': instance.photos?.map((e) => e.toJson()).toList(),
    };
