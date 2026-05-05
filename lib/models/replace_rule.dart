import 'package:json_annotation/json_annotation.dart';
import 'json_helpers.dart';

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

  factory ReplaceRule.fromJson(Map<String, dynamic> json) => ReplaceRule(
        id: toInt(json['id']),
        group: toStringVal(json['group']),
        name: toStringVal(json['name']),
        replaceRegex: toStringVal(json['replaceRegex']),
        replacement: toStringVal(json['replacement']),
        scope: toStringVal(json['scope']),
        isEnabled: toBool(json['isEnabled']),
        isRegex: toBool(json['isRegex']),
        sortOrder: toInt(json['sortOrder']),
        order: toInt(json['order']),
      );

  Map<String, dynamic> toJson() => _$ReplaceRuleToJson(this);
}
