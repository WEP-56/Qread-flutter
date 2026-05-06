import 'package:flutter/material.dart';

import '../../services/local_cache_service.dart';
import '../../services/storage_service.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({Key? key}) : super(key: key);

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  int _chapterCacheCount = 5;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await StorageService.instance;
    if (!mounted) return;
    setState(() {
      _chapterCacheCount = storage.readerChapterCacheCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('常规设置')),
      body: ListView(
        children: [
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.cached_outlined),
                  title: Text('缓存管理'),
                ),
                ListTile(
                  title: const Text('缓存章节数'),
                  subtitle: Text('当前 $_chapterCacheCount 章'),
                  trailing: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 3, label: Text('3')),
                      ButtonSegment(value: 5, label: Text('5')),
                      ButtonSegment(value: 8, label: Text('8')),
                    ],
                    selected: {_chapterCacheCount},
                    onSelectionChanged: (values) =>
                        _saveChapterCacheCount(values.first),
                  ),
                ),
                ListTile(
                  title: const Text('缓存清理'),
                  subtitle: const Text('清理书架、发现、订阅和阅读章节本地缓存'),
                  trailing: _clearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  onTap: _clearing ? null : _confirmClearCache,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChapterCacheCount(int count) async {
    final storage = await StorageService.instance;
    await storage.setReaderChapterCacheCount(count);
    if (!mounted) return;
    setState(() => _chapterCacheCount = count);
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('清理缓存'),
            content: const Text('将清理本地列表缓存和章节缓存，不会删除账号、设置和书架数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('清理'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _clearing = true);
    await LocalCacheService.instance.clearAllCaches();
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存已清理')),
    );
  }
}
