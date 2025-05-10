// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'private_race_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PrivateRaceModel _$PrivateRaceModelFromJson(Map<String, dynamic> json) {
  return _PrivateRaceModel.fromJson(json);
}

/// @nodoc
mixin _$PrivateRaceModel {
  int? get id => throw _privateConstructorUsedError;
  String? get roomName =>
      throw _privateConstructorUsedError; // Internal room identifier?
  String? get specialRaceRoomName =>
      throw _privateConstructorUsedError; // Display name for the race
  String? get description => throw _privateConstructorUsedError;
  String? get imagePath =>
      throw _privateConstructorUsedError; // URL for the race image
  String? get type => throw _privateConstructorUsedError; // e.g., "outdoor"
  int? get duration =>
      throw _privateConstructorUsedError; // Duration in minutes? Check API details
  DateTime? get startTime => throw _privateConstructorUsedError;
  String? get giftPoll => throw _privateConstructorUsedError;
  String? get giftPollList => throw _privateConstructorUsedError;

  /// Serializes this PrivateRaceModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrivateRaceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrivateRaceModelCopyWith<PrivateRaceModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrivateRaceModelCopyWith<$Res> {
  factory $PrivateRaceModelCopyWith(
          PrivateRaceModel value, $Res Function(PrivateRaceModel) then) =
      _$PrivateRaceModelCopyWithImpl<$Res, PrivateRaceModel>;
  @useResult
  $Res call(
      {int? id,
      String? roomName,
      String? specialRaceRoomName,
      String? description,
      String? imagePath,
      String? type,
      int? duration,
      DateTime? startTime,
      String? giftPoll,
      String? giftPollList});
}

/// @nodoc
class _$PrivateRaceModelCopyWithImpl<$Res, $Val extends PrivateRaceModel>
    implements $PrivateRaceModelCopyWith<$Res> {
  _$PrivateRaceModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrivateRaceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? roomName = freezed,
    Object? specialRaceRoomName = freezed,
    Object? description = freezed,
    Object? imagePath = freezed,
    Object? type = freezed,
    Object? duration = freezed,
    Object? startTime = freezed,
    Object? giftPoll = freezed,
    Object? giftPollList = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      roomName: freezed == roomName
          ? _value.roomName
          : roomName // ignore: cast_nullable_to_non_nullable
              as String?,
      specialRaceRoomName: freezed == specialRaceRoomName
          ? _value.specialRaceRoomName
          : specialRaceRoomName // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      imagePath: freezed == imagePath
          ? _value.imagePath
          : imagePath // ignore: cast_nullable_to_non_nullable
              as String?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      giftPoll: freezed == giftPoll
          ? _value.giftPoll
          : giftPoll // ignore: cast_nullable_to_non_nullable
              as String?,
      giftPollList: freezed == giftPollList
          ? _value.giftPollList
          : giftPollList // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PrivateRaceModelImplCopyWith<$Res>
    implements $PrivateRaceModelCopyWith<$Res> {
  factory _$$PrivateRaceModelImplCopyWith(_$PrivateRaceModelImpl value,
          $Res Function(_$PrivateRaceModelImpl) then) =
      __$$PrivateRaceModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      String? roomName,
      String? specialRaceRoomName,
      String? description,
      String? imagePath,
      String? type,
      int? duration,
      DateTime? startTime,
      String? giftPoll,
      String? giftPollList});
}

/// @nodoc
class __$$PrivateRaceModelImplCopyWithImpl<$Res>
    extends _$PrivateRaceModelCopyWithImpl<$Res, _$PrivateRaceModelImpl>
    implements _$$PrivateRaceModelImplCopyWith<$Res> {
  __$$PrivateRaceModelImplCopyWithImpl(_$PrivateRaceModelImpl _value,
      $Res Function(_$PrivateRaceModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of PrivateRaceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? roomName = freezed,
    Object? specialRaceRoomName = freezed,
    Object? description = freezed,
    Object? imagePath = freezed,
    Object? type = freezed,
    Object? duration = freezed,
    Object? startTime = freezed,
    Object? giftPoll = freezed,
    Object? giftPollList = freezed,
  }) {
    return _then(_$PrivateRaceModelImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      roomName: freezed == roomName
          ? _value.roomName
          : roomName // ignore: cast_nullable_to_non_nullable
              as String?,
      specialRaceRoomName: freezed == specialRaceRoomName
          ? _value.specialRaceRoomName
          : specialRaceRoomName // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      imagePath: freezed == imagePath
          ? _value.imagePath
          : imagePath // ignore: cast_nullable_to_non_nullable
              as String?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int?,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      giftPoll: freezed == giftPoll
          ? _value.giftPoll
          : giftPoll // ignore: cast_nullable_to_non_nullable
              as String?,
      giftPollList: freezed == giftPollList
          ? _value.giftPollList
          : giftPollList // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PrivateRaceModelImpl implements _PrivateRaceModel {
  const _$PrivateRaceModelImpl(
      {this.id,
      this.roomName,
      this.specialRaceRoomName,
      this.description,
      this.imagePath,
      this.type,
      this.duration,
      this.startTime,
      this.giftPoll,
      this.giftPollList});

  factory _$PrivateRaceModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrivateRaceModelImplFromJson(json);

  @override
  final int? id;
  @override
  final String? roomName;
// Internal room identifier?
  @override
  final String? specialRaceRoomName;
// Display name for the race
  @override
  final String? description;
  @override
  final String? imagePath;
// URL for the race image
  @override
  final String? type;
// e.g., "outdoor"
  @override
  final int? duration;
// Duration in minutes? Check API details
  @override
  final DateTime? startTime;
  @override
  final String? giftPoll;
  @override
  final String? giftPollList;

  @override
  String toString() {
    return 'PrivateRaceModel(id: $id, roomName: $roomName, specialRaceRoomName: $specialRaceRoomName, description: $description, imagePath: $imagePath, type: $type, duration: $duration, startTime: $startTime, giftPoll: $giftPoll, giftPollList: $giftPollList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrivateRaceModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomName, roomName) ||
                other.roomName == roomName) &&
            (identical(other.specialRaceRoomName, specialRaceRoomName) ||
                other.specialRaceRoomName == specialRaceRoomName) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imagePath, imagePath) ||
                other.imagePath == imagePath) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.giftPoll, giftPoll) ||
                other.giftPoll == giftPoll) &&
            (identical(other.giftPollList, giftPollList) ||
                other.giftPollList == giftPollList));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      roomName,
      specialRaceRoomName,
      description,
      imagePath,
      type,
      duration,
      startTime,
      giftPoll,
      giftPollList);

  /// Create a copy of PrivateRaceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrivateRaceModelImplCopyWith<_$PrivateRaceModelImpl> get copyWith =>
      __$$PrivateRaceModelImplCopyWithImpl<_$PrivateRaceModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrivateRaceModelImplToJson(
      this,
    );
  }
}

abstract class _PrivateRaceModel implements PrivateRaceModel {
  const factory _PrivateRaceModel(
      {final int? id,
      final String? roomName,
      final String? specialRaceRoomName,
      final String? description,
      final String? imagePath,
      final String? type,
      final int? duration,
      final DateTime? startTime,
      final String? giftPoll,
      final String? giftPollList}) = _$PrivateRaceModelImpl;

  factory _PrivateRaceModel.fromJson(Map<String, dynamic> json) =
      _$PrivateRaceModelImpl.fromJson;

  @override
  int? get id;
  @override
  String? get roomName; // Internal room identifier?
  @override
  String? get specialRaceRoomName; // Display name for the race
  @override
  String? get description;
  @override
  String? get imagePath; // URL for the race image
  @override
  String? get type; // e.g., "outdoor"
  @override
  int? get duration; // Duration in minutes? Check API details
  @override
  DateTime? get startTime;
  @override
  String? get giftPoll;
  @override
  String? get giftPollList;

  /// Create a copy of PrivateRaceModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrivateRaceModelImplCopyWith<_$PrivateRaceModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
