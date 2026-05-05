import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

part 'search_result.g.dart';

@JsonSerializable()
class SearchResult {
  @JsonKey(name: 'bookUrl')
  String? bookUrl;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'author')
  String? author;

  @JsonKey(name: 'coverUrl')
  String? coverUrl;

  @JsonKey(name: 'intro')
  String? intro;

  @JsonKey(name: 'kind')
  String? kind;

  @JsonKey(name: 'latestChapterTitle')
  String? latestChapterTitle;

  @JsonKey(name: 'tocUrl')
  String? tocUrl;

  @JsonKey(name: 'origin')
  String? origin;

  @JsonKey(name: 'originName')
  String? originName;

  @JsonKey(name: 'wordCount')
  String? wordCount;

  SearchResult({
    this.bookUrl,
    this.name,
    this.author,
    this.coverUrl,
    this.intro,
    this.kind,
    this.latestChapterTitle,
    this.tocUrl,
    this.origin,
    this.originName,
    this.wordCount,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        bookUrl: toStringVal(json['bookUrl']),
        name: toStringVal(json['name']),
        author: toStringVal(json['author']),
        coverUrl: toStringVal(json['coverUrl']),
        intro: toStringVal(json['intro']),
        kind: toStringVal(json['kind']),
        latestChapterTitle: toStringVal(json['latestChapterTitle']),
        tocUrl: toStringVal(json['tocUrl']),
        origin: toStringVal(json['origin']),
        originName: toStringVal(json['originName']),
        wordCount: toStringVal(json['wordCount']),
      );

  Map<String, dynamic> toJson() => _$SearchResultToJson(this);
}
