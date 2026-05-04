// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'replace_rule.dart';

ReplaceRule _$ReplaceRuleFromJson(Map<String, dynamic> json) => ReplaceRule(
      id: json['id'] as int?,
      group: json['group'] as String?,
      name: json['name'] as String?,
      replaceRegex: json['replaceRegex'] as String?,
      replacement: json['replacement'] as String?,
      scope: json['scope'] as String?,
      isEnabled: json['isEnabled'] as bool?,
      isRegex: json['isRegex'] as bool?,
      sortOrder: json['sortOrder'] as int?,
      order: json['order'] as int?,
    );

Map<String, dynamic> _$ReplaceRuleToJson(ReplaceRule instance) => <String, dynamic>{
      'id': instance.id,
      'group': instance.group,
      'name': instance.name,
      'replaceRegex': instance.replaceRegex,
      'replacement': instance.replacement,
      'scope': instance.scope,
      'isEnabled': instance.isEnabled,
      'isRegex': instance.isRegex,
      'sortOrder': instance.sortOrder,
      'order': instance.order,
    };
