import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

part 'rss_article.g.dart';

@JsonSerializable()
class RssArticle {
  @JsonKey(name: 'origin')
  String? origin;

  @JsonKey(name: 'sort')
  String? sort;

  @JsonKey(name: 'title')
  String? title;

  @JsonKey(name: 'order')
  int? order;

  @JsonKey(name: 'link')
  String? link;

  @JsonKey(name: 'pubDate')
  String? pubDate;

  @JsonKey(name: 'description')
  String? description;

  @JsonKey(name: 'content')
  String? content;

  @JsonKey(name: 'image')
  String? image;

  @JsonKey(name: 'read')
  bool? read;

  RssArticle({
    this.origin,
    this.sort,
    this.title,
    this.order,
    this.link,
    this.pubDate,
    this.description,
    this.content,
    this.image,
    this.read,
  });

  factory RssArticle.fromJson(Map<String, dynamic> json) => RssArticle(
        origin: toStringVal(json['origin']),
        sort: toStringVal(json['sort']),
        title: toStringVal(json['title']),
        order: toInt(json['order']),
        link: toStringVal(json['link']),
        pubDate: toStringVal(json['pubDate']),
        description: toStringVal(json['description']),
        content: toStringVal(json['content']),
        image: toStringVal(json['image']),
        read: toBool(json['read']),
      );

  Map<String, dynamic> toJson() => _$RssArticleToJson(this);
}
