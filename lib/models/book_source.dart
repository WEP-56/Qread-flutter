import 'package:json_annotation/json_annotation.dart';

part 'book_source.g.dart';

@JsonSerializable()
class BookSource {
  @JsonKey(name: 'bookSourceUrl')
  String? bookSourceUrl;

  @JsonKey(name: 'bookSourceName')
  String? bookSourceName;

  @JsonKey(name: 'bookSourceGroup')
  String? bookSourceGroup;

  @JsonKey(name: 'bookSourceType')
  int? bookSourceType;

  @JsonKey(name: 'bookSourceComment')
  String? bookSourceComment;

  @JsonKey(name: 'searchUrl')
  String? searchUrl;

  @JsonKey(name: 'exploreUrl')
  String? exploreUrl;

  @JsonKey(name: 'ruleSearch')
  dynamic ruleSearch;

  @JsonKey(name: 'ruleExplore')
  dynamic ruleExplore;

  @JsonKey(name: 'ruleBookInfo')
  dynamic ruleBookInfo;

  @JsonKey(name: 'ruleToc')
  dynamic ruleToc;

  @JsonKey(name: 'ruleContent')
  dynamic ruleContent;

  @JsonKey(name: 'enabled')
  bool? enabled;

  @JsonKey(name: 'enabledExplore')
  bool? enabledExplore;

  @JsonKey(name: 'customOrder')
  int? customOrder;

  @JsonKey(name: 'lastUpdateTime')
  int? lastUpdateTime;

  @JsonKey(name: 'respondTime')
  int? respondTime;

  @JsonKey(name: 'weight')
  int? weight;

  @JsonKey(name: 'variable')
  String? variable;

  @JsonKey(name: 'header')
  String? header;

  @JsonKey(name: 'loginUrl')
  String? loginUrl;

  @JsonKey(name: 'loginUi')
  String? loginUi;

  @JsonKey(name: 'loginCheckJs')
  String? loginCheckJs;

  BookSource({
    this.bookSourceUrl,
    this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType,
    this.bookSourceComment,
    this.searchUrl,
    this.exploreUrl,
    this.ruleSearch,
    this.ruleExplore,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.enabled,
    this.enabledExplore,
    this.customOrder,
    this.lastUpdateTime,
    this.respondTime,
    this.weight,
    this.variable,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
  });

  factory BookSource.fromJson(Map<String, dynamic> json) =>
      _$BookSourceFromJson(json);
  Map<String, dynamic> toJson() => _$BookSourceToJson(this);
}
