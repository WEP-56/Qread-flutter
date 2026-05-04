// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_group.dart';

BookGroup _$BookGroupFromJson(Map<String, dynamic> json) => BookGroup(
      groupId: json['groupId'] as int?,
      groupName: json['groupName'] as String?,
      order: json['order'] as int?,
      show: json['show'] as bool?,
    );

Map<String, dynamic> _$BookGroupToJson(BookGroup instance) => <String, dynamic>{
      'groupId': instance.groupId,
      'groupName': instance.groupName,
      'order': instance.order,
      'show': instance.show,
    };
