import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/api_service.dart';

class SourceManageProvider extends ChangeNotifier {
  List<BookSource> _sources = [];
  bool _loading = false;
  bool _canEdit = false;
  String? _error;

  // Multi-select state
  final Set<String> _selectedIds = {};
  bool _selectMode = false;

  // Search/filter
  String _searchQuery = '';
  String _filterGroup = '';

  String get filterGroup => _filterGroup;

  List<BookSource> get sources => _sources;
  bool get loading => _loading;
  bool get canEdit => _canEdit;
  String? get error => _error;
  Set<String> get selectedIds => _selectedIds;
  bool get selectMode => _selectMode;

  int get enabledCount => _sources.where((s) => s.enabled == true).length;
  int get exploreEnabledCount => _sources.where((s) => s.enabledExplore == true).length;

  List<BookSource> get filteredSources {
    var list = _sources;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return (s.bookSourceName ?? '').toLowerCase().contains(q) ||
            (s.bookSourceUrl ?? '').toLowerCase().contains(q) ||
            (s.bookSourceGroup ?? '').toLowerCase().contains(q) ||
            (s.bookSourceComment ?? '').toLowerCase().contains(q);
      }).toList();
    }
    if (_filterGroup.isNotEmpty) {
      list = list.where((s) => s.bookSourceGroup == _filterGroup).toList();
    }
    return list;
  }

  List<String> get allGroups {
    final groups = <String>{};
    for (final s in _sources) {
      final g = (s.bookSourceGroup ?? '').trim();
      if (g.isNotEmpty) groups.add(g);
    }
    final sorted = groups.toList()..sort();
    return sorted;
  }

  Map<String, List<BookSource>> get groupedSources {
    final groups = <String, List<BookSource>>{};
    for (final source in filteredSources) {
      final groupName = (source.bookSourceGroup ?? '').trim().isEmpty
          ? '未分组'
          : source.bookSourceGroup!.trim();
      groups.putIfAbsent(groupName, () => []).add(source);
    }
    final sortedEntries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in sortedEntries) e.key: e.value};
  }

  // ============ Search/filter ============

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterGroup(String group) {
    _filterGroup = group == _filterGroup ? '' : group;
    notifyListeners();
  }

  // ============ Selection ============

  void toggleSelectMode() {
    _selectMode = !_selectMode;
    if (!_selectMode) _selectedIds.clear();
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

  void selectAll() {
    _selectedIds.clear();
    for (final s in filteredSources) {
      if (s.bookSourceUrl != null) _selectedIds.add(s.bookSourceUrl!);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _selectMode = false;
    notifyListeners();
  }

  // ============ Data loading ============

  Future<void> loadSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    if (refresh) _sources = [];
    notifyListeners();

    try {
      final permissionFuture = ApiService.instance.getCanSource(accessToken);
      final pageData = await ApiService.instance.getBookSourcesPage(accessToken);
      final data = pageData['data'] ?? pageData;
      final md5 = data['md5']?.toString();
      final totalPages = int.tryParse(data['page']?.toString() ?? '1') ?? 1;

      List<BookSource> allSources = [];
      if (md5 != null) {
        for (int page = 1; page <= totalPages; page++) {
          final pageSources = await ApiService.instance.getBookSourcesNew(
            accessToken,
            md5: md5,
            page: page,
          );
          if (pageSources.isEmpty) break;
          allSources.addAll(pageSources);
        }
      }
      if (allSources.isEmpty) {
        allSources = await ApiService.instance.getBookSources(accessToken);
      }

      _canEdit = await permissionFuture;
      _sources = allSources;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ============ Single operations ============

  Future<bool> toggleEnabled(String accessToken, BookSource source) async {
    final id = source.bookSourceUrl;
    if (id == null) return false;
    final st = source.enabled == true ? 0 : 1;
    try {
      final result = await ApiService.instance.stopbookSource(accessToken, id, st: st);
      if (result['isSuccess'] == true) {
        source.enabled = st == 1;
        notifyListeners();
        return true;
      }
      _error = result['errorMsg'] ?? '操作失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleExploreEnabled(String accessToken, BookSource source) async {
    final id = source.bookSourceUrl;
    if (id == null) return false;
    try {
      Map<String, dynamic> result;
      if (source.enabledExplore == true) {
        result = await ApiService.instance.stopbookSourceExplores(accessToken, [id]);
      } else {
        result = await ApiService.instance.startbookSourceExplores(accessToken, [id]);
      }
      if (result['isSuccess'] == true) {
        source.enabledExplore = !(source.enabledExplore == true);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSource(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.delbookSource(accessToken, id);
      if (result['isSuccess'] == true) {
        _sources.removeWhere((s) => s.bookSourceUrl == id);
        _selectedIds.remove(id);
        notifyListeners();
        return true;
      }
      _error = result['errorMsg'] ?? '删除失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> topSourceItem(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.topSource(accessToken, id);
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

  Future<bool> bottomSourceItem(String accessToken, String id) async {
    try {
      final result = await ApiService.instance.bottomSource(accessToken, id);
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

  // ============ Batch operations ============

  Future<bool> batchDelete(String accessToken) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result = await ApiService.instance.delbookSources(accessToken, ids);
      if (result['isSuccess'] == true) {
        _sources.removeWhere((s) => ids.contains(s.bookSourceUrl));
        _selectedIds.clear();
        notifyListeners();
        return true;
      }
      _error = result['errorMsg'] ?? '批量删除失败';
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
          ? await ApiService.instance.startbookSources(accessToken, ids)
          : await ApiService.instance.stopbookSources(accessToken, ids);
      if (result['isSuccess'] == true) {
        for (final s in _sources) {
          if (ids.contains(s.bookSourceUrl)) s.enabled = enabled;
        }
        _selectedIds.clear();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> batchSetExploreEnabled(String accessToken, bool enabled) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result = enabled
          ? await ApiService.instance.startbookSourceExplores(accessToken, ids)
          : await ApiService.instance.stopbookSourceExplores(accessToken, ids);
      if (result['isSuccess'] == true) {
        for (final s in _sources) {
          if (ids.contains(s.bookSourceUrl)) s.enabledExplore = enabled;
        }
        _selectedIds.clear();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> batchTop(String accessToken) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result = await ApiService.instance.topallSource(accessToken, ids);
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

  Future<bool> batchBottom(String accessToken) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result = await ApiService.instance.bottomallSource(accessToken, ids);
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

  Future<bool> batchEditGroup(String accessToken, {required String st, String? group}) async {
    if (_selectedIds.isEmpty) return false;
    try {
      final ids = _selectedIds.toList();
      final result = await ApiService.instance.editsourcegroup(
        accessToken,
        st: st,
        group: group,
        ids: ids,
      );
      if (result['isSuccess'] == true) {
        await loadSources(accessToken, refresh: true);
        return true;
      }
      _error = result['errorMsg'] ?? '修改分组失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Import / Export ============

  Future<String?> importSources(String accessToken, String jsonContent) async {
    try {
      final result = await ApiService.instance.saveBookSources(accessToken, jsonContent);
      if (result['isSuccess'] == true) {
        await loadSources(accessToken, refresh: true);
        return result['errorMsg']?.toString();
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

  Future<String?> exportSelectedSources(String accessToken) async {
    if (_selectedIds.isEmpty) return null;
    try {
      final result = await ApiService.instance.getbookSourcejson(accessToken, _selectedIds.toList());
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

  Future<Map<String, dynamic>?> getSourceDetail(String accessToken, String id) async {
    try {
      return await ApiService.instance.getbookSources(accessToken, id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> editSource(String accessToken, {String? id, required String json}) async {
    try {
      final result = await ApiService.instance.editbookSources(accessToken, id: id, json: json);
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
