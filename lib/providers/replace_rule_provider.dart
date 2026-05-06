import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/replace_rule.dart';
import '../services/api_service.dart';

class ReplaceRuleProvider extends ChangeNotifier {
  static const ungroupedFilter = '__ungrouped__';

  final Set<String> _selectedIds = <String>{};
  final List<ReplaceRule> _rules = <ReplaceRule>[];

  bool _loading = false;
  bool _selectMode = false;
  String _searchQuery = '';
  String _filterGroup = '';
  String? _error;

  List<ReplaceRule> get rules => _rules;
  bool get loading => _loading;
  bool get selectMode => _selectMode;
  String get filterGroup => _filterGroup;
  String? get error => _error;
  Set<String> get selectedIds => _selectedIds;

  List<ReplaceRule> get filteredRules {
    var list = List<ReplaceRule>.from(_rules);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((rule) {
        return rule.name.toLowerCase().contains(query) ||
            (rule.groupName ?? '').toLowerCase().contains(query) ||
            rule.pattern.toLowerCase().contains(query) ||
            (rule.scope ?? '').toLowerCase().contains(query);
      }).toList();
    }
    if (_filterGroup == ungroupedFilter) {
      list =
          list.where((rule) => _splitGroups(rule.groupName).isEmpty).toList();
    } else if (_filterGroup.isNotEmpty) {
      list = list
          .where((rule) => _splitGroups(rule.groupName).contains(_filterGroup))
          .toList();
    }
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  List<String> get allGroups {
    final groups = <String>{};
    for (final rule in _rules) {
      groups.addAll(_splitGroups(rule.groupName));
    }
    final list = groups.toList()..sort();
    return list;
  }

  int get enabledCount => _rules.where((rule) => rule.isEnabled).length;

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilterGroup(String value) {
    _filterGroup = value;
    notifyListeners();
  }

  void toggleSelectMode() {
    _selectMode = !_selectMode;
    if (!_selectMode) {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _selectMode = false;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAllFiltered() {
    _selectedIds
      ..clear()
      ..addAll(filteredRules.map((rule) => rule.id).whereType<String>());
    notifyListeners();
  }

  void invertSelection() {
    final ids =
        filteredRules.map((rule) => rule.id).whereType<String>().toList();
    final next = <String>{};
    for (final id in ids) {
      if (!_selectedIds.contains(id)) {
        next.add(id);
      }
    }
    _selectedIds
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> loadRules(String accessToken, {bool refresh = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    if (refresh) _rules.clear();
    notifyListeners();

    try {
      final pageData =
          await ApiService.instance.getReplaceRulesPage(accessToken);
      final data = pageData['data'] ?? pageData;
      final md5 = data['md5']?.toString();
      final totalPages = int.tryParse(data['page']?.toString() ?? '1') ?? 1;
      final fetched = <ReplaceRule>[];

      for (var page = 1; page <= totalPages; page++) {
        final pageRules = await ApiService.instance.getReplaceRulesNew(
          accessToken,
          md5: md5,
          page: page,
        );
        if (pageRules.isEmpty) break;
        fetched.addAll(pageRules);
      }

      _rules
        ..clear()
        ..addAll(fetched);
      _rules.sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveRule(String accessToken, ReplaceRule rule) async {
    try {
      final result =
          await ApiService.instance.addReplaceRule(accessToken, rule);
      if (result['isSuccess'] == true) {
        await loadRules(accessToken, refresh: true);
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '保存失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> importRules(String accessToken, String content) async {
    try {
      final normalized = _normalizeImportJson(content);
      final result = await ApiService.instance.saveReplaceRulesRaw(
        accessToken,
        normalized,
      );
      if (result['isSuccess'] == true) {
        await loadRules(accessToken, refresh: true);
        return result['errorMsg']?.toString() ?? '导入成功';
      }
      _error = result['errorMsg']?.toString() ?? '导入失败';
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> toggleEnabled(String accessToken, ReplaceRule rule) async {
    final id = rule.id;
    if (id == null || id.isEmpty) return false;
    try {
      final result = await ApiService.instance.stopReplaceRule(
        accessToken,
        id,
        st: rule.isEnabled ? 0 : 1,
      );
      if (result['isSuccess'] == true) {
        await loadRules(accessToken, refresh: true);
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '操作失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRule(String accessToken, String id) async {
    try {
      final result =
          await ApiService.instance.deleteReplaceRule(accessToken, id);
      if (result['isSuccess'] == true) {
        _rules.removeWhere((rule) => rule.id == id);
        _selectedIds.remove(id);
        notifyListeners();
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '删除失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> topRule(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.topReplaceRule(accessToken, id);
      if (result['isSuccess'] == true) {
        await loadRules(accessToken, refresh: true);
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '置顶失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> batchDelete(String accessToken) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result =
          await ApiService.instance.deleteReplaceRules(accessToken, ids);
      if (result['isSuccess'] == true) {
        _rules.removeWhere((rule) => ids.contains(rule.id));
        _selectedIds.clear();
        notifyListeners();
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '批量删除失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> batchSetEnabled(String accessToken, bool enabled) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result = enabled
          ? await ApiService.instance.startReplaceRulesByIds(accessToken, ids)
          : await ApiService.instance.stopReplaceRulesByIds(accessToken, ids);
      if (result['isSuccess'] == true) {
        await loadRules(accessToken, refresh: true);
        _selectedIds.clear();
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '批量操作失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  List<String> _splitGroups(String? groupName) {
    if (groupName == null || groupName.trim().isEmpty) return const <String>[];
    return groupName
        .split(RegExp(r'[,;，；]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalizeImportJson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '[]';

    final decoded = jsonDecode(text);
    final normalized = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          normalized.add(
            ReplaceRule.fromJson(Map<String, dynamic>.from(item))
                .toServerJson(),
          );
        }
      }
    } else if (decoded is Map) {
      normalized.add(
        ReplaceRule.fromJson(Map<String, dynamic>.from(decoded)).toServerJson(),
      );
    }
    return const JsonEncoder.withIndent('  ').convert(normalized);
  }
}
