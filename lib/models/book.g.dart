// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializable Generator
// **************************************************************************

Book _$BookFromJson(Map<String, dynamic> json) => Book(
      bookUrl: json['bookUrl'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      customCoverUrl: json['customCoverUrl'] as String?,
      tocUrl: json['tocUrl'] as String?,
      origin: json['origin'] as String?,
      originName: json['originName'] as String?,
      type: json['type'] as int?,
      group: json['group'] as int?,
      latestChapterTitle: json['latestChapterTitle'] as String?,
      latestChapterTime: json['latestChapterTime'] as int?,
      lastCheckTime: json['lastCheckTime'] as int?,
      lastCheckCount: json['lastCheckCount'] as int?,
      totalChapterNum: json['totalChapterNum'] as int?,
      durChapterTitle: json['durChapterTitle'] as String?,
      durChapterIndex: json['durChapterIndex'] as int?,
      durChapterPos: json['durChapterPos'] as int?,
      canUpdate: json['canUpdate'] as bool?,
      order: json['order'] as int?,
      variable: json['variable'] as String?,
    );

Map<String, dynamic> _$BookToJson(Book instance) => <String, dynamic>{
      'bookUrl': instance.bookUrl,
      'name': instance.name,
      'author': instance.author,
      'coverUrl': instance.coverUrl,
      'intro': instance.intro,
      'customCoverUrl': instance.customCoverUrl,
      'tocUrl': instance.tocUrl,
      'origin': instance.origin,
      'originName': instance.originName,
      'type': instance.type,
      'group': instance.group,
      'latestChapterTitle': instance.latestChapterTitle,
      'latestChapterTime': instance.latestChapterTime,
      'lastCheckTime': instance.lastCheckTime,
      'lastCheckCount': instance.lastCheckCount,
      'totalChapterNum': instance.totalChapterNum,
      'durChapterTitle': instance.durChapterTitle,
      'durChapterIndex': instance.durChapterIndex,
      'durChapterPos': instance.durChapterPos,
      'canUpdate': instance.canUpdate,
      'order': instance.order,
      'variable': instance.variable,
    };
