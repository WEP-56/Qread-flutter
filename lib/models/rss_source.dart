import 'package:json_annotation/json_annotation.dart';

part 'rss_source.g.dart';

@JsonSerializable()
class RssSource {
  @JsonKey(name: 'sourceUrl')
  String? sourceUrl;

  @JsonKey(name: 'sourceName')
  String? sourceName;

  @JsonKey(name: 'sourceIcon')
  String? sourceIcon;

  @JsonKey(name: 'sourceGroup')
  String? sourceGroup;

  @JsonKey(name: 'sourceComment')
  String? sourceComment;

  @JsonKey(name: 'enabled')
  bool? enabled;

  @JsonKey(name: 'sortUrl')
  String? sortUrl;

  @JsonKey(name: 'articleStyle')
  int? articleStyle;

  @JsonKey(name: 'customOrder')
  int? customOrder;

  @JsonKey(name: 'singleUrl')
  bool? singleUrl;

  @JsonKey(name: 'enableJs')
  bool? enableJs;

  @JsonKey(name: 'loadWithBaseUrl')
  bool? loadWithBaseUrl;

  @JsonKey(name: 'enabledLoadWithBaseUrl')
  bool? enabledLoadWithBaseUrl;

  @JsonKey(name: 'header')
  String? header;

  @JsonKey(name: 'loginUrl')
  String? loginUrl;

  @JsonKey(name: 'loginUi')
  String? loginUi;

  @JsonKey(name: 'loginCheckJs')
  String? loginCheckJs;

  @JsonKey(name: 'variable')
  String? variable;

  @JsonKey(name: 'variableComment')
  String? variableComment;

  RssSource({
    this.sourceUrl,
    this.sourceName,
    this.sourceIcon,
    this.sourceGroup,
    this.sourceComment,
    this.enabled,
    this.sortUrl,
    this.articleStyle,
    this.customOrder,
    this.singleUrl,
    this.enableJs,
    this.loadWithBaseUrl,
    this.enabledLoadWithBaseUrl,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.variable,
    this.variableComment,
  });

  factory RssSource.fromJson(Map<String, dynamic> json) =>
      _$RssSourceFromJson(json);
  Map<String, dynamic> toJson() => _$RssSourceToJson(this);
}
