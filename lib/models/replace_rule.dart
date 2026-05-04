import 'package:json_annotation/json_annotation.dart';

part 'replace_rule.g.dart';

@JsonSerializable()
class ReplaceRule {
  @JsonKey(name: 'id')
  int? id;

  @JsonKey(name: 'group')
  String? group;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'replaceRegex')
  String? replaceRegex;

  @JsonKey(name: 'replacement')
  String? replacement;

  @JsonKey(name: 'scope')
  String? scope;

  @JsonKey(name: 'isEnabled')
  bool? isEnabled;

  @JsonKey(name: 'isRegex')
  bool? isRegex;

  @JsonKey(name: 'sortOrder')
  int? sortOrder;

  @JsonKey(name: 'order')
  int? order;

  ReplaceRule({
    this.id,
    this.group,
    this.name,
    this.replaceRegex,
    this.replacement,
    this.scope,
    this.isEnabled,
    this.isRegex,
    this.sortOrder,
    this.order,
  });

  factory ReplaceRule.fromJson(Map<String, dynamic> json) =>
      _$ReplaceRuleFromJson(json);
  Map<String, dynamic> toJson() => _$ReplaceRuleToJson(this);
}
