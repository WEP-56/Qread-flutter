import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

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

  @JsonKey(name: 'variableComment')
  String? variableComment;

  @JsonKey(name: 'checkKeyWord')
  String? checkKeyWord;

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
    this.variableComment,
    this.checkKeyWord,
  });

  factory BookSource.fromJson(Map<String, dynamic> json) => BookSource(
        bookSourceUrl: toStringVal(json['bookSourceUrl']),
        bookSourceName: toStringVal(json['bookSourceName']),
        bookSourceGroup: toStringVal(json['bookSourceGroup']),
        bookSourceType: toInt(json['bookSourceType']),
        bookSourceComment: toStringVal(json['bookSourceComment']),
        searchUrl: toStringVal(json['searchUrl']),
        exploreUrl: toStringVal(json['exploreUrl']),
        ruleSearch: json['ruleSearch'],
        ruleExplore: json['ruleExplore'],
        ruleBookInfo: json['ruleBookInfo'],
        ruleToc: json['ruleToc'],
        ruleContent: json['ruleContent'],
        enabled: toBool(json['enabled']),
        enabledExplore: toBool(json['enabledExplore']),
        customOrder: toInt(json['customOrder']),
        lastUpdateTime: toInt(json['lastUpdateTime']),
        respondTime: toInt(json['respondTime']),
        weight: toInt(json['weight']),
        variable: toStringVal(json['variable']),
        header: toStringVal(json['header']),
        loginUrl: toStringVal(json['loginUrl']),
        loginUi: toStringVal(json['loginUi']),
        loginCheckJs: toStringVal(json['loginCheckJs']),
        variableComment: toStringVal(json['variableComment']),
        checkKeyWord: toStringVal(json['checkKeyWord']),
      );

  Map<String, dynamic> toJson() => _$BookSourceToJson(this);
}
