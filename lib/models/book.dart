import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

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

  @JsonKey(name: 'useReplaceRule')
  bool? useReplaceRule;

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
    this.useReplaceRule,
    this.variable,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        bookUrl: toStringVal(json['bookUrl']),
        name: toStringVal(json['name']),
        author: toStringVal(json['author']),
        coverUrl: toStringVal(json['coverUrl']),
        intro: toStringVal(json['intro']),
        customCoverUrl: toStringVal(json['customCoverUrl']),
        tocUrl: toStringVal(json['tocUrl']),
        origin: toStringVal(json['origin']),
        originName: toStringVal(json['originName']),
        type: toInt(json['type']),
        group: toInt(json['group']),
        latestChapterTitle: toStringVal(json['latestChapterTitle']),
        latestChapterTime: toInt(json['latestChapterTime']),
        lastCheckTime: toInt(json['lastCheckTime']),
        lastCheckCount: toInt(json['lastCheckCount']),
        totalChapterNum: toInt(json['totalChapterNum']),
        durChapterTitle: toStringVal(json['durChapterTitle']),
        durChapterIndex: toInt(json['durChapterIndex']),
        durChapterPos: toInt(json['durChapterPos']),
        canUpdate: toBool(json['canUpdate']),
        order: toInt(json['order']),
        useReplaceRule: toBool(json['useReplaceRule']),
        variable: toStringVal(json['variable']),
      );

  Map<String, dynamic> toJson() => _$BookToJson(this);
}
