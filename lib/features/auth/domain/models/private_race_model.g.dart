// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_race_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PrivateRaceModelImpl _$$PrivateRaceModelImplFromJson(
        Map<String, dynamic> json) =>
    _$PrivateRaceModelImpl(
      id: (json['id'] as num?)?.toInt(),
      roomName: json['roomName'] as String?,
      specialRaceRoomName: json['specialRaceRoomName'] as String?,
      description: json['description'] as String?,
      imagePath: json['imagePath'] as String?,
      type: json['type'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      startTime: json['startTime'] == null
          ? null
          : DateTime.parse(json['startTime'] as String),
      giftPoll: json['giftPoll'] as String?,
      giftPollList: json['giftPollList'] as String?,
    );

Map<String, dynamic> _$$PrivateRaceModelImplToJson(
        _$PrivateRaceModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomName': instance.roomName,
      'specialRaceRoomName': instance.specialRaceRoomName,
      'description': instance.description,
      'imagePath': instance.imagePath,
      'type': instance.type,
      'duration': instance.duration,
      'startTime': instance.startTime?.toIso8601String(),
      'giftPoll': instance.giftPoll,
      'giftPollList': instance.giftPollList,
    };
