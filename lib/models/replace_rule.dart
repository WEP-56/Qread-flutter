import 'json_helpers.dart';

class ReplaceRule {
  final String? id;
  final String name;
  final String? groupName;
  final String pattern;
  final String replacement;
  final String? scope;
  final bool scopeTitle;
  final bool scopeContent;
  final String? excludeScope;
  final bool isEnabled;
  final bool isRegex;
  final int timeoutMillisecond;
  final int order;

  const ReplaceRule({
    this.id,
    this.name = '',
    this.groupName,
    this.pattern = '',
    this.replacement = '',
    this.scope,
    this.scopeTitle = false,
    this.scopeContent = true,
    this.excludeScope,
    this.isEnabled = true,
    this.isRegex = true,
    this.timeoutMillisecond = 3000,
    this.order = 0,
  });

  factory ReplaceRule.fromJson(Map<String, dynamic> json) {
    final pattern = toStringVal(json['pattern']) ??
        toStringVal(json['replaceRegex']) ??
        toStringVal(json['regex']) ??
        '';
    return ReplaceRule(
      id: toStringVal(json['id']),
      name: toStringVal(json['name']) ??
          toStringVal(json['replaceSummary']) ??
          '',
      groupName: toStringVal(json['groupname']) ?? toStringVal(json['group']),
      pattern: pattern,
      replacement: toStringVal(json['replacement']) ?? '',
      scope: toStringVal(json['scope']) ?? toStringVal(json['useTo']),
      scopeTitle: toBool(json['scopeTitle']) ?? false,
      scopeContent: toBool(json['scopeContent']) ?? true,
      excludeScope: toStringVal(json['excludeScope']),
      isEnabled: toBool(json['isEnabled']) ?? toBool(json['enable']) ?? true,
      isRegex: toBool(json['isRegex']) ?? true,
      timeoutMillisecond: toInt(json['timeoutMillisecond']) ?? 3000,
      order: toInt(json['ruleorder']) ??
          toInt(json['sortOrder']) ??
          toInt(json['serialNumber']) ??
          toInt(json['order']) ??
          0,
    );
  }

  Map<String, dynamic> toServerJson() => <String, dynamic>{
        if (id != null && id!.isNotEmpty) 'id': id,
        'name': name,
        'groupname':
            groupName?.trim().isEmpty == true ? null : groupName?.trim(),
        'pattern': pattern,
        'replacement': replacement,
        'scope': scope?.trim().isEmpty == true ? null : scope?.trim(),
        'scopeTitle': scopeTitle,
        'scopeContent': scopeContent,
        'excludeScope':
            excludeScope?.trim().isEmpty == true ? null : excludeScope?.trim(),
        'isEnabled': isEnabled,
        'isRegex': isRegex,
        'timeoutMillisecond': timeoutMillisecond,
        'ruleorder': order,
      };

  Map<String, dynamic> toExportJson() => <String, dynamic>{
        if (id != null && id!.isNotEmpty) 'id': id,
        'name': name,
        'group': groupName,
        'pattern': pattern,
        'replacement': replacement,
        'scope': scope,
        'scopeTitle': scopeTitle,
        'scopeContent': scopeContent,
        'excludeScope': excludeScope,
        'isEnabled': isEnabled,
        'isRegex': isRegex,
        'timeoutMillisecond': timeoutMillisecond,
        'order': order,
      };

  ReplaceRule copyWith({
    String? id,
    String? name,
    String? groupName,
    String? pattern,
    String? replacement,
    String? scope,
    bool? scopeTitle,
    bool? scopeContent,
    String? excludeScope,
    bool? isEnabled,
    bool? isRegex,
    int? timeoutMillisecond,
    int? order,
  }) {
    return ReplaceRule(
      id: id ?? this.id,
      name: name ?? this.name,
      groupName: groupName ?? this.groupName,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      scope: scope ?? this.scope,
      scopeTitle: scopeTitle ?? this.scopeTitle,
      scopeContent: scopeContent ?? this.scopeContent,
      excludeScope: excludeScope ?? this.excludeScope,
      isEnabled: isEnabled ?? this.isEnabled,
      isRegex: isRegex ?? this.isRegex,
      timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
      order: order ?? this.order,
    );
  }

  bool matchesScope({
    required String bookName,
    required String bookOrigin,
    required bool forTitle,
  }) {
    if (!isEnabled) return false;
    if (forTitle && !scopeTitle) return false;
    if (!forTitle && !scopeContent) return false;

    final scopeText = scope?.trim() ?? '';
    if (scopeText.isNotEmpty &&
        !scopeText.contains(bookName) &&
        !scopeText.contains(bookOrigin)) {
      return false;
    }

    final excludeText = excludeScope?.trim() ?? '';
    if (excludeText.isNotEmpty &&
        (excludeText.contains(bookName) || excludeText.contains(bookOrigin))) {
      return false;
    }
    return true;
  }

  String get displayName {
    final group = groupName?.trim();
    if (group == null || group.isEmpty) return name;
    return '$name [$group]';
  }
}
