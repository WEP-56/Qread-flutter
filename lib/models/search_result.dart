import 'package:json_annotation/json_annotation.dart';

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

  factory SearchResult.fromJson(Map<String, dynamic> json) =>
      _$SearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$SearchResultToJson(this);
}
