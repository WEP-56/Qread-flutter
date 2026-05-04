// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rss_article.dart';

RssArticle _$RssArticleFromJson(Map<String, dynamic> json) => RssArticle(
      origin: json['origin'] as String?,
      sort: json['sort'] as String?,
      title: json['title'] as String?,
      order: json['order'] as int?,
      link: json['link'] as String?,
      pubDate: json['pubDate'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      image: json['image'] as String?,
      read: json['read'] as bool?,
    );

Map<String, dynamic> _$RssArticleToJson(RssArticle instance) => <String, dynamic>{
      'origin': instance.origin,
      'sort': instance.sort,
      'title': instance.title,
      'order': instance.order,
      'link': instance.link,
      'pubDate': instance.pubDate,
      'description': instance.description,
      'content': instance.content,
      'image': instance.image,
      'read': instance.read,
    };
