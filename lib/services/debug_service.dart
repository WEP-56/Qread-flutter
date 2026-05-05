import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/constants.dart';

class DebugService {
  WebSocket? _socket;
  final StreamController<String> _logController = StreamController<String>.broadcast();
  bool _disposed = false;
  Completer<void>? _done;

  Stream<String> get logStream => _logController.stream;
  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  Future<void> startBookDebug({
    required String accessToken,
    required String sourceUrl,
    required String key,
  }) async {
    await _disconnect();
    _done = Completer<void>();

    final wsUrl = _wsUrl('/debug?id=$accessToken');
    try {
      _socket = await WebSocket.connect(wsUrl);
      _socket!.listen(
        (data) {
          if (_disposed) return;
          final text = data is String ? data : utf8.decode(data as List<int>);
          _parseAndEmit(text);
        },
        onDone: () {
          if (!_disposed) {
            _logController.add('--- 调试结束 ---');
            _done?.complete();
          }
        },
        onError: (error) {
          if (!_disposed) {
            _logController.add('连接错误: $error');
            _done?.completeError(error);
          }
        },
        cancelOnError: true,
      );

      final msg = jsonEncode({'url': sourceUrl, 'key': key});
      _socket!.add(msg);
    } catch (e) {
      _logController.add('连接失败: $e');
      _done?.completeError(e);
    }
  }

  Future<void> startRssDebug({
    required String accessToken,
    required String sourceUrl,
  }) async {
    await _disconnect();
    _done = Completer<void>();

    final wsUrl = _wsUrl('/rssdebug?id=$accessToken');
    try {
      _socket = await WebSocket.connect(wsUrl);
      _socket!.listen(
        (data) {
          if (_disposed) return;
          final text = data is String ? data : utf8.decode(data as List<int>);
          _parseAndEmit(text);
        },
        onDone: () {
          if (!_disposed) {
            _logController.add('--- 调试结束 ---');
            _done?.complete();
          }
        },
        onError: (error) {
          if (!_disposed) {
            _logController.add('连接错误: $error');
            _done?.completeError(error);
          }
        },
        cancelOnError: true,
      );

      final msg = jsonEncode({'url': sourceUrl});
      _socket!.add(msg);
    } catch (e) {
      _logController.add('连接失败: $e');
      _done?.completeError(e);
    }
  }

  void _parseAndEmit(String text) {
    // WebSocket messages are newline-delimited JSON: {"msg":"..."}\n\n
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final json = jsonDecode(trimmed);
        if (json is Map && json.containsKey('msg')) {
          _logController.add(json['msg'].toString());
        } else {
          _logController.add(trimmed);
        }
      } catch (_) {
        _logController.add(trimmed);
      }
    }
  }

  String _wsUrl(String path) {
    final base = AppConstants.apiBase;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final basePath = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
    return '$scheme://$host$port$basePath$path';
  }

  Future<void> cancel() async {
    await _disconnect();
    _logController.add('--- 已取消 ---');
  }

  Future<void> _disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    if (_done != null && !_done!.isCompleted) {
      _done!.complete();
    }
  }

  void dispose() {
    _disposed = true;
    _disconnect();
    _logController.close();
  }
}
