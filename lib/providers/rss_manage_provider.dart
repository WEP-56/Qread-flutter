import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/rss_source.dart';
import '../services/api_service.dart';

class RssManageProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  bool _loading = false;
  bool _canEdit = false;
  String? _error;
  String _searchQuery = '';
  String _filterGroup = '';

  List<RssSource> get sources => _sources;
  bool get loading => _loading;
  bool get canEdit => _canEdit;
  String? get error => _error;
  String get filterGroup => _filterGroup;

  int get enabledCount => _sources.where((s) => s.enabled == true).length;

  List<String> get allGroups {
    final groups = <String>{};
    for (final source in _sources) {
      final group = (source.sourceGroup ?? '').trim();
      if (group.isNotEmpty) groups.add(group);
    }
    final sorted = groups.toList()..sort();
    return sorted;
  }

  List<RssSource> get filteredSources {
    var list = _sources;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((source) {
        return (source.sourceName ?? '').toLowerCase().contains(query) ||
            (source.sourceUrl ?? '').toLowerCase().contains(query) ||
            (source.sourceComment ?? '').toLowerCase().contains(query) ||
            (source.sourceGroup ?? '').toLowerCase().contains(query);
      }).toList();
    }
    if (_filterGroup.isNotEmpty) {
      list = list.where((source) => source.sourceGroup == _filterGroup).toList();
    }
    return list;
  }

  Map<String, List<RssSource>> get groupedSources {
    final groups = <String, List<RssSource>>{};
    for (final source in filteredSources) {
      final groupName = (source.sourceGroup ?? '').trim().isEmpty
          ? '未分组'
          : source.sourceGroup!.trim();
      groups.putIfAbsent(groupName, () => []).add(source);
    }
    final sortedEntries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in sortedEntries) entry.key: entry.value};
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilterGroup(String group) {
    _filterGroup = group == _filterGroup ? '' : group;
    notifyListeners();
  }

  Future<void> loadSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    if (refresh) _sources = [];
    notifyListeners();

    try {
      final canEditFuture = ApiService.instance.getRssCanEdit(accessToken);
      final pageData = await ApiService.instance.getRssSourcesPage(accessToken);
      final data = pageData['data'] ?? pageData;
      final md5 = data['md5']?.toString();
      final totalPages = int.tryParse(data['page']?.toString() ?? '1') ?? 1;

      List<RssSource> allSources = [];
      if (md5 != null) {
        for (int page = 1; page <= totalPages; page++) {
          final pageSources = await ApiService.instance.getRssSourcesNew(
            accessToken,
            md5: md5,
            page: page,
          );
          if (pageSources.isEmpty) break;
          allSources.addAll(pageSources);
        }
      }

      if (allSources.isEmpty) {
        allSources = await ApiService.instance.getRssSources(accessToken);
      }

      _canEdit = await canEditFuture;
      _sources = allSources;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> importSources(String accessToken, String jsonContent) async {
    try {
      final normalized = _normalizeImportJson(jsonContent);
      final result = await ApiService.instance.saveRssSources(
        accessToken,
        source: normalized,
        urls: '',
      );
      if (result['isSuccess'] == true) {
        await loadSources(accessToken, refresh: true);
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

  String _normalizeImportJson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '[]';
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return jsonEncode(decoded);
      if (decoded is Map) return jsonEncode([decoded]);
    } catch (_) {}
    return text;
  }

  Future<bool> toggleEnabled(String accessToken, RssSource source) async {
    final id = source.sourceUrl;
    if (id == null) return false;
    try {
      final result = await ApiService.instance.stopRssSource(
        accessToken,
        id,
        st: source.enabled == true ? 0 : 1,
      );
      if (result['isSuccess'] == true) {
        source.enabled = !(source.enabled == true);
        notifyListeners();
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

  Future<bool> deleteSource(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.delRssSource(accessToken, id);
      if (result['isSuccess'] == true) {
        _sources.removeWhere((source) => source.sourceUrl == id);
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

  Future<bool> topSource(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.topRssSource(accessToken, id);
      if (result['isSuccess'] == true) {
        await loadSources(accessToken, refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> bottomSource(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.bottomRssSource(accessToken, id);
      if (result['isSuccess'] == true) {
        await loadSources(accessToken, refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSourceDetail(String accessToken, String id) async {
    try {
      return await ApiService.instance.getRssType(accessToken, id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> exportAll(String accessToken) async {
    try {
      final ids = _sources.map((source) => source.sourceUrl).whereType<String>().toList();
      if (ids.isEmpty) return null;
      final result = await ApiService.instance.getRssSourcejson(accessToken, ids);
      if (result['isSuccess'] == true) {
        return result['data']?.toString();
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> exportOne(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.getRssSourcejson(accessToken, [id]);
      if (result['isSuccess'] == true) {
        return result['data']?.toString();
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> editSource(String accessToken, {String? id, required String json}) async {
    try {
      final result = await ApiService.instance.editRssSources(
        accessToken,
        id: id,
        json: json,
      );
      if (result['isSuccess'] == true) {
        await loadSources(accessToken, refresh: true);
        return true;
      }
      _error = result['errorMsg']?.toString() ?? '编辑失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
