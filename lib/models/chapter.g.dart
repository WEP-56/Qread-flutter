// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

Chapter _$ChapterFromJson(Map<String, dynamic> json) => Chapter(
      bookUrl: json['bookUrl'] as String?,
      title: json['title'] as String?,
      chapterIndex: json['chapterIndex'] as int?,
      isVolume: json['isVolume'] as bool?,
      isVip: json['isVip'] as bool?,
      resourceUrl: json['resourceUrl'] as String?,
      tag: json['tag'] as String?,
    );

Map<String, dynamic> _$ChapterToJson(Chapter instance) => <String, dynamic>{
      'bookUrl': instance.bookUrl,
      'title': instance.title,
      'chapterIndex': instance.chapterIndex,
      'isVolume': instance.isVolume,
      'isVip': instance.isVip,
      'resourceUrl': instance.resourceUrl,
      'tag': instance.tag,
    };
