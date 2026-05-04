// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result.dart';

SearchResult _$SearchResultFromJson(Map<String, dynamic> json) => SearchResult(
      bookUrl: json['bookUrl'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      latestChapterTitle: json['latestChapterTitle'] as String?,
      tocUrl: json['tocUrl'] as String?,
      origin: json['origin'] as String?,
      originName: json['originName'] as String?,
      wordCount: json['wordCount'] as String?,
    );

Map<String, dynamic> _$SearchResultToJson(SearchResult instance) => <String, dynamic>{
      'bookUrl': instance.bookUrl,
      'name': instance.name,
      'author': instance.author,
      'coverUrl': instance.coverUrl,
      'intro': instance.intro,
      'kind': instance.kind,
      'latestChapterTitle': instance.latestChapterTitle,
      'tocUrl': instance.tocUrl,
      'origin': instance.origin,
      'originName': instance.originName,
      'wordCount': instance.wordCount,
    };
