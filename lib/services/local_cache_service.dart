import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalCacheService {
  static LocalCacheService? _instance;

  LocalCacheService._();

  static LocalCacheService get instance => _instance ??= LocalCacheService._();

  Future<Directory> _rootDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}local_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String scopedKey(String raw) => _fnv1a64(raw);

  Future<void> saveJson(String key, Object data) async {
    final file = await _jsonFile(key);
    await file.writeAsString(const JsonEncoder().convert(data), flush: true);
  }

  Future<List<dynamic>?> readJsonList(String key) async {
    final file = await _jsonFile(key);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readJsonObject(String key) async {
    final file = await _jsonFile(key);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required bool useReplaceRule,
    required String content,
  }) async {
    final file = await _chapterFile(bookUrl, chapterIndex, useReplaceRule);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  Future<String?> readChapterContent({
    required String bookUrl,
    required int chapterIndex,
    required bool useReplaceRule,
  }) async {
    final file = await _chapterFile(bookUrl, chapterIndex, useReplaceRule);
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> pruneChapterCache({
    required String bookUrl,
    required bool useReplaceRule,
    required Set<int> keepIndices,
  }) async {
    final directory = await _chapterDir(bookUrl, useReplaceRule);
    if (!await directory.exists()) return;
    final entries = await directory.list().toList();
    for (final entry in entries) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      final index = int.tryParse(name.replaceAll('.txt', ''));
      if (index == null || keepIndices.contains(index)) continue;
      await entry.delete();
    }
  }

  Future<void> clearAllCaches() async {
    final root = await _rootDir();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  Future<File> _jsonFile(String key) async {
    final root = await _rootDir();
    return File('${root.path}${Platform.pathSeparator}$key.json');
  }

  Future<Directory> _chapterDir(String bookUrl, bool useReplaceRule) async {
    final root = await _rootDir();
    final hashed = scopedKey(bookUrl);
    final replaceFlag = useReplaceRule ? 'replace_on' : 'replace_off';
    return Directory(
      '${root.path}${Platform.pathSeparator}reader${Platform.pathSeparator}$hashed${Platform.pathSeparator}$replaceFlag',
    );
  }

  Future<File> _chapterFile(
    String bookUrl,
    int chapterIndex,
    bool useReplaceRule,
  ) async {
    final dir = await _chapterDir(bookUrl, useReplaceRule);
    return File(
      '${dir.path}${Platform.pathSeparator}$chapterIndex.txt',
    );
  }

  String _fnv1a64(String input) {
    const offsetBasis = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offsetBasis;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
