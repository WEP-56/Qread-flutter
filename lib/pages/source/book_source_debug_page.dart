import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/debug_service.dart';

class BookSourceDebugPage extends StatefulWidget {
  final Map<String, String> args;

  const BookSourceDebugPage({Key? key, required this.args}) : super(key: key);

  @override
  State<BookSourceDebugPage> createState() => _BookSourceDebugPageState();
}

class _BookSourceDebugPageState extends State<BookSourceDebugPage> {
  final _debugService = DebugService();
  final _keyController = TextEditingController();
  final _logLines = <String>[];
  final _scrollController = ScrollController();
  StreamSubscription<String>? _logSub;
  bool _debugging = false;
  String? _error;

  String get _sourceUrl => widget.args['sourceUrl'] ?? '';
  String get _sourceName => widget.args['sourceName'] ?? '书源';
  String get _checkKeyWord => widget.args['checkKeyWord'] ?? '系统';
  String get _exploreUrl => widget.args['exploreUrl'] ?? '';

  @override
  void initState() {
    super.initState();
    _keyController.text = _checkKeyWord;
    _logSub = _debugService.logStream.listen((msg) {
      if (!mounted) return;
      setState(() {
        _logLines.add(msg);
        if (msg == '--- 调试结束 ---' || msg == '--- 已取消 ---') {
          _debugging = false;
        }
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _keyController.dispose();
    _scrollController.dispose();
    _debugService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startDebug({String? key}) async {
    final searchKey = key ?? _keyController.text.trim();
    if (searchKey.isEmpty && !searchKey.startsWith('++') && !searchKey.startsWith('--')) {
      setState(() => _error = '请输入搜索关键词');
      return;
    }

    final token = context.read<UserProvider>().token ?? '';
    setState(() {
      _debugging = true;
      _error = null;
      _logLines.clear();
      _logLines.add('开始调试: $_sourceName');
      _logLines.add('搜索关键词: $searchKey');
      _logLines.add('');
    });

    try {
      await _debugService.startBookDebug(
        accessToken: token,
        sourceUrl: _sourceUrl,
        key: searchKey,
      );
    } catch (_) {}
  }

  void _runQuickAction(String key) {
    _keyController.text = key;
    _startDebug(key: key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('调试 - $_sourceName'),
        actions: [
          if (_debugging)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: '取消',
              onPressed: () => _debugService.cancel(),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildHelpPanel(),
          const Divider(height: 1),
          Expanded(child: _buildLogArea()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                hintText: '输入搜索关键词 ( ++ 开头=目录调试, -- 开头=正文调试 )',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _startDebug(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _debugging ? null : () => _startDebug(),
            child: Text(_debugging ? '调试中...' : '开始调试'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpPanel() {
    final hasDiscover = _exploreUrl.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷测试', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: Text('关键词: $_checkKeyWord'),
                  onPressed: () => _runQuickAction(_checkKeyWord),
                ),
                ActionChip(
                  label: const Text('系统'),
                  onPressed: () => _runQuickAction('系统'),
                ),
                if (hasDiscover)
                  ActionChip(
                    label: const Text('发现'),
                    onPressed: () => _runQuickAction(_exploreUrl),
                  ),
                ActionChip(
                  label: const Text('目录调试'),
                  onPressed: () => _runQuickAction('++任意书籍URL'),
                ),
                ActionChip(
                  label: const Text('正文调试'),
                  onPressed: () => _runQuickAction('--任意章节URL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogArea() {
    if (_logLines.isEmpty && !_debugging) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('输入关键词开始调试', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Column(
      children: [
        if (_debugging)
          const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _logLines.length,
            itemBuilder: (context, index) {
              final line = _logLines[index];
              return SelectableText(
                line,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: line.startsWith('---') ? Colors.grey : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
