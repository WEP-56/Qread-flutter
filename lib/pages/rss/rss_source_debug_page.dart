import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/debug_service.dart';

class RssSourceDebugPage extends StatefulWidget {
  final Map<String, String> args;

  const RssSourceDebugPage({Key? key, required this.args}) : super(key: key);

  @override
  State<RssSourceDebugPage> createState() => _RssSourceDebugPageState();
}

class _RssSourceDebugPageState extends State<RssSourceDebugPage> {
  final _debugService = DebugService();
  final _logLines = <String>[];
  final _scrollController = ScrollController();
  StreamSubscription<String>? _logSub;
  bool _debugging = false;
  bool _started = false;

  String get _sourceUrl => widget.args['sourceUrl'] ?? '';
  String get _sourceName => widget.args['sourceName'] ?? '订阅源';

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDebug());
  }

  @override
  void dispose() {
    _logSub?.cancel();
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

  Future<void> _startDebug() async {
    if (_started) return;
    _started = true;

    final token = context.read<UserProvider>().token ?? '';
    setState(() {
      _debugging = true;
      _logLines.clear();
      _logLines.add('开始 RSS 调试: $_sourceName');
      _logLines.add('');
    });

    try {
      await _debugService.startRssDebug(
        accessToken: token,
        sourceUrl: _sourceUrl,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RSS 调试 - $_sourceName'),
        actions: [
          if (_debugging)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新调试',
              onPressed: () {
                _started = false;
                _startDebug();
              },
            ),
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
          if (_debugging) const LinearProgressIndicator(),
          Expanded(
            child: _logLines.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
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
      ),
    );
  }
}
