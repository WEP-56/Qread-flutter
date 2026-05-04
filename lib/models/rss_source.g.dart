// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rss_source.dart';

RssSource _$RssSourceFromJson(Map<String, dynamic> json) => RssSource(
      sourceUrl: json['sourceUrl'] as String?,
      sourceName: json['sourceName'] as String?,
      sourceIcon: json['sourceIcon'] as String?,
      sourceGroup: json['sourceGroup'] as String?,
      sourceComment: json['sourceComment'] as String?,
      enabled: json['enabled'] as bool?,
      sortUrl: json['sortUrl'] as String?,
      articleStyle: json['articleStyle'] as int?,
      customOrder: json['customOrder'] as int?,
      singleUrl: json['singleUrl'] as bool?,
      enableJs: json['enableJs'] as bool?,
      loadWithBaseUrl: json['loadWithBaseUrl'] as bool?,
      enabledLoadWithBaseUrl: json['enabledLoadWithBaseUrl'] as bool?,
      header: json['header'] as String?,
      loginUrl: json['loginUrl'] as String?,
      loginUi: json['loginUi'] as String?,
      loginCheckJs: json['loginCheckJs'] as String?,
      variable: json['variable'] as String?,
      variableComment: json['variableComment'] as String?,
    );

Map<String, dynamic> _$RssSourceToJson(RssSource instance) => <String, dynamic>{
      'sourceUrl': instance.sourceUrl,
      'sourceName': instance.sourceName,
      'sourceIcon': instance.sourceIcon,
      'sourceGroup': instance.sourceGroup,
      'sourceComment': instance.sourceComment,
      'enabled': instance.enabled,
      'sortUrl': instance.sortUrl,
      'articleStyle': instance.articleStyle,
      'customOrder': instance.customOrder,
      'singleUrl': instance.singleUrl,
      'enableJs': instance.enableJs,
      'loadWithBaseUrl': instance.loadWithBaseUrl,
      'enabledLoadWithBaseUrl': instance.enabledLoadWithBaseUrl,
      'header': instance.header,
      'loginUrl': instance.loginUrl,
      'loginUi': instance.loginUi,
      'loginCheckJs': instance.loginCheckJs,
      'variable': instance.variable,
      'variableComment': instance.variableComment,
    };
