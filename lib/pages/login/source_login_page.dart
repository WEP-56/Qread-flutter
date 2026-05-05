import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/row_ui.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'webview_login_page.dart';

class SourceLoginPageArgs {
  final String sourceUrl;
  final String sourceName;
  final String type; // "bookSource" or "rssSource"
  final String? loginUi;
  final String? loginUrl;
  final String? variableComment;
  final String? header;

  const SourceLoginPageArgs({
    required this.sourceUrl,
    required this.sourceName,
    required this.type,
    this.loginUi,
    this.loginUrl,
    this.variableComment,
    this.header,
  });

  Map<String, String> get headerMap {
    if (header == null || header!.isEmpty) return {};
    try {
      final map = jsonDecode(header!);
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }
}

class SourceLoginPage extends StatefulWidget {
  final SourceLoginPageArgs args;

  const SourceLoginPage({Key? key, required this.args}) : super(key: key);

  @override
  State<SourceLoginPage> createState() => _SourceLoginPageState();
}

class _SourceLoginPageState extends State<SourceLoginPage> {
  final _formKey = GlobalKey<FormState>();
  List<RowUi> _rows = [];
  Map<String, String> _loginData = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isBookSource => widget.args.type == 'bookSource';

  @override
  void initState() {
    super.initState();
    _loadLoginUi();
  }

  Future<void> _loadLoginUi() async {
    setState(() => _loading = true);
    try {
      final api = ApiService.instance;
      final token = context.read<UserProvider>().token ?? '';

      if (widget.args.loginUi != null && widget.args.loginUi!.isNotEmpty) {
        _rows = parseLoginUi(widget.args.loginUi);
      } else {
        // Fetch from backend
        Map<String, dynamic> resp;
        if (_isBookSource) {
          resp = await api.getSourcesloginui(token, url: widget.args.sourceUrl);
        } else {
          resp = await api.getRssSourcesloginui(token, widget.args.sourceUrl);
        }
        final data = resp['data'];
        if (data is String && data.isNotEmpty) {
          _rows = parseLoginUi(data);
        } else if (data is List) {
          _rows = data.map((e) => RowUi.fromJson(e is Map<String, dynamic> ? e : {})).toList();
        }
      }

      _loginData = defaultLoginData(_rows);

      // Load existing login info
      if (_isBookSource) {
        final resp = await api.getSourcesLoginInfo(token, widget.args.sourceUrl);
        final data = resp['data'];
        if (data is String && data.isNotEmpty && data != '{}') {
          _fillFromSaved(data);
        }
      } else {
        final resp = await api.getRssLoginInfo(token, widget.args.sourceUrl);
        final data = resp['data'];
        if (data is String && data.isNotEmpty && data != '{}') {
          _fillFromSaved(data);
        }
      }
    } catch (e) {
      // Still show the form even if loading saved data fails
      if (widget.args.loginUi != null && widget.args.loginUi!.isNotEmpty) {
        _rows = parseLoginUi(widget.args.loginUi);
        _loginData = defaultLoginData(_rows);
      }
    }
    setState(() => _loading = false);
  }

  void _fillFromSaved(String json) {
    try {
      final map = Uri.tryParse('?$json')?.queryParameters;
      if (map != null) {
        setState(() {
          for (final entry in map.entries) {
            if (_loginData.containsKey(entry.key)) {
              _loginData[entry.key] = entry.value;
            }
          }
        });
        return;
      }
    } catch (_) {}
    try {
      final map = Map<String, dynamic>.from(
        jsonDecode(json) as Map,
      );
      setState(() {
        for (final entry in map.entries) {
          if (_loginData.containsKey(entry.key)) {
            _loginData[entry.key] = entry.value?.toString() ?? '';
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _handleButtonAction(RowUi row) async {
    if (row.action == null) return;
    final action = row.action!;

    // Sync current form values before reading _loginData
    _formKey.currentState!.save();

    // Check if it's an absolute URL
    if (action.startsWith('http://') || action.startsWith('https://')) {
      final uri = Uri.tryParse(action);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Non-URL action: treat as JS, send to backend
    try {
      final api = ApiService.instance;
      final token = context.read<UserProvider>().token ?? '';
      if (_isBookSource) {
        await api.sourcesAction(
          token,
          bookSourceUrl: widget.args.sourceUrl,
          action: action,
          info: _encodeLoginData(),
        );
      } else {
        // RSS: save login info first, then execute action
        await api.putRssLoginInfo(
            token, widget.args.sourceUrl, _encodeLoginData());
        await api.rssaction(token, widget.args.sourceUrl, action);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('动作 "${row.name}" 已执行')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('动作执行失败: $e')),
        );
      }
    }
  }

  Future<void> _saveLoginData() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);
    try {
      final api = ApiService.instance;
      final token = context.read<UserProvider>().token ?? '';
      final info = _encodeLoginData();

      if (_isBookSource) {
        await api.putSourcesLoginInfo(token, widget.args.sourceUrl, info);
      } else {
        await api.putRssLoginInfo(token, widget.args.sourceUrl, info);
        // Also execute login if loginUrl exists
        if (widget.args.loginUrl != null && widget.args.loginUrl!.isNotEmpty) {
          await api.rssaction(token, widget.args.sourceUrl, 'login');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录信息已保存')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _encodeLoginData() {
    final filtered = <String, String>{};
    _loginData.forEach((key, value) {
      if (value.isNotEmpty) filtered[key] = value;
    });
    return jsonEncode(filtered);
  }

  Future<void> _navigateToWebLogin() async {
    final result = await Navigator.of(context).pushNamed(
      '/source/weblogin',
      arguments: WebViewLoginPageArgs(
        sourceUrl: widget.args.sourceUrl,
        sourceName: widget.args.sourceName,
        type: widget.args.type,
        loginUrl: widget.args.loginUrl ?? widget.args.sourceUrl,
        headers: widget.args.headerMap,
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _showVariableDialog() async {
    final api = ApiService.instance;
    final token = context.read<UserProvider>().token ?? '';

    String currentValue = '';
    try {
      if (_isBookSource) {
        final resp = await api.getSourcesVariable(token, widget.args.sourceUrl);
        currentValue = resp['data']?.toString() ?? '';
      } else {
        final resp = await api.getRssVariable(token, widget.args.sourceUrl);
        currentValue = resp['data']?.toString() ?? '';
      }
    } catch (_) {}

    if (!mounted) return;

    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('源变量'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.args.variableComment != null &&
                widget.args.variableComment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.args.variableComment!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入变量值',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        if (_isBookSource) {
          await api.setSourcesVariable(token, widget.args.sourceUrl, result);
        } else {
          await api.setRssVariable(token, widget.args.sourceUrl, result);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('变量已保存')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('变量保存失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登录 - ${widget.args.sourceName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: '源变量',
            onPressed: _showVariableDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLoginUi,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('该源没有登录表单'),
                          const SizedBox(height: 16),
                          if (widget.args.loginUrl != null &&
                              widget.args.loginUrl!.isNotEmpty)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.language),
                              label: const Text('使用网页登录'),
                              onPressed: _navigateToWebLogin,
                            ),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ..._rows.map(_buildRow),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildRow(RowUi row) {
    if (row.isButton) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _handleButtonAction(row),
          child: Text(row.name),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: _loginData[row.name] ?? '',
        obscureText: row.isPassword,
        decoration: InputDecoration(
          labelText: row.name,
          border: const OutlineInputBorder(),
        ),
        onSaved: (value) => _loginData[row.name] = value ?? '',
        validator: (value) => null,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('保存登录信息'),
          onPressed: _saving ? null : _saveLoginData,
        ),
        const SizedBox(height: 12),
        if (widget.args.loginUrl != null &&
            widget.args.loginUrl!.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.language),
            label: const Text('使用网页登录'),
            onPressed: _navigateToWebLogin,
          ),
      ],
    );
  }
}
