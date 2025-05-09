import 'package:json_annotation/json_annotation.dart';

part 'photo.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, nullable: true)
class Photo {
  final int? id;
  @JsonKey(defaultValue: '')
  final String url;
  @JsonKey(defaultValue: false)
  final bool isMain;

  const Photo({
    this.id,
    required this.url,
    required this.isMain,
  });

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  Map<String, dynamic> toJson() => _$PhotoToJson(this);
}
