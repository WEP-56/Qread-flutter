import 'package:json_annotation/json_annotation.dart';

part 'book.g.dart';

@JsonSerializable()
class Book {
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

  @JsonKey(name: 'customCoverUrl')
  String? customCoverUrl;

  @JsonKey(name: 'tocUrl')
  String? tocUrl;

  @JsonKey(name: 'origin')
  String? origin;

  @JsonKey(name: 'originName')
  String? originName;

  @JsonKey(name: 'type')
  int? type;

  @JsonKey(name: 'group')
  int? group;

  @JsonKey(name: 'latestChapterTitle')
  String? latestChapterTitle;

  @JsonKey(name: 'latestChapterTime')
  int? latestChapterTime;

  @JsonKey(name: 'lastCheckTime')
  int? lastCheckTime;

  @JsonKey(name: 'lastCheckCount')
  int? lastCheckCount;

  @JsonKey(name: 'totalChapterNum')
  int? totalChapterNum;

  @JsonKey(name: 'durChapterTitle')
  String? durChapterTitle;

  @JsonKey(name: 'durChapterIndex')
  int? durChapterIndex;

  @JsonKey(name: 'durChapterPos')
  int? durChapterPos;

  @JsonKey(name: 'canUpdate')
  bool? canUpdate;

  @JsonKey(name: 'order')
  int? order;

  @JsonKey(name: 'variable')
  String? variable;

  Book({
    this.bookUrl,
    this.name,
    this.author,
    this.coverUrl,
    this.intro,
    this.customCoverUrl,
    this.tocUrl,
    this.origin,
    this.originName,
    this.type,
    this.group,
    this.latestChapterTitle,
    this.latestChapterTime,
    this.lastCheckTime,
    this.lastCheckCount,
    this.totalChapterNum,
    this.durChapterTitle,
    this.durChapterIndex,
    this.durChapterPos,
    this.canUpdate,
    this.order,
    this.variable,
  });

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
  Map<String, dynamic> toJson() => _$BookToJson(this);
}
