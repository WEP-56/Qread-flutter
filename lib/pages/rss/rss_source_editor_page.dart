import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/rss_manage_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../login/source_login_page.dart';
import '../source/source_editor_support.dart';

class RssSourceEditorPageArgs {
  final String title;
  final String? id;
  final String? initialJson;

  const RssSourceEditorPageArgs({
    required this.title,
    this.id,
    this.initialJson,
  });
}

class RssSourceEditorPage extends StatefulWidget {
  final RssSourceEditorPageArgs args;

  const RssSourceEditorPage({Key? key, required this.args}) : super(key: key);

  @override
  State<RssSourceEditorPage> createState() => _RssSourceEditorPageState();
}

class _RssSourceEditorPageState extends State<RssSourceEditorPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, dynamic> _data = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  static const _tabs = ['基本', '列表', 'WEBVIEW'];

  static const _basicFields = [
    SourceEditorField(path: 'sourceName', label: '源名称 (sourceName)'),
    SourceEditorField(path: 'sourceUrl', label: '源 URL (sourceUrl)'),
    SourceEditorField(path: 'sourceIcon', label: '图标 (sourceIcon)'),
    SourceEditorField(path: 'sourceGroup', label: '源分组 (sourceGroup)'),
    SourceEditorField(path: 'sourceComment', label: '源注释 (sourceComment)', maxLines: 4),
    SourceEditorField(path: 'enabled', label: '启用', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'singleUrl', label: '单 URL', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'enabledCookieJar', label: 'CookieJar', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'enableJs', label: '启用 JS', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'loadWithBaseUrl', label: '以 baseUrl 加载', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'sortUrl', label: '分类 URL (sortUrl)', maxLines: 3),
    SourceEditorField(path: 'loginUrl', label: '登录 URL (loginUrl)', maxLines: 5),
    SourceEditorField(path: 'loginUi', label: '登录 UI (loginUi)', maxLines: 6),
    SourceEditorField(path: 'loginCheckJs', label: '登录校验 JS (loginCheckJs)', maxLines: 5),
    SourceEditorField(path: 'coverDecodeJs', label: '封面解码 JS (coverDecodeJs)', maxLines: 5),
    SourceEditorField(path: 'header', label: '请求头 (header)', maxLines: 5),
    SourceEditorField(path: 'variableComment', label: '变量说明 (variableComment)', maxLines: 4),
    SourceEditorField(path: 'concurrentRate', label: '并发率 (concurrentRate)'),
    SourceEditorField(path: 'jsLib', label: 'jsLib', maxLines: 8),
  ];

  static const _listFields = [
    SourceEditorField(path: 'ruleArticles', label: '文章列表规则 (ruleArticles)', maxLines: 4),
    SourceEditorField(path: 'ruleNextPage', label: '下一页规则 (ruleNextPage)', maxLines: 2),
    SourceEditorField(path: 'ruleTitle', label: '标题规则 (ruleTitle)', maxLines: 2),
    SourceEditorField(path: 'rulePubDate', label: '时间规则 (rulePubDate)', maxLines: 2),
    SourceEditorField(path: 'ruleDescription', label: '简介规则 (ruleDescription)', maxLines: 3),
    SourceEditorField(path: 'ruleImage', label: '图片规则 (ruleImage)', maxLines: 2),
    SourceEditorField(path: 'ruleLink', label: '链接规则 (ruleLink)', maxLines: 2),
  ];

  static const _webViewFields = [
    SourceEditorField(path: 'ruleContent', label: '正文规则 (ruleContent)', maxLines: 5),
    SourceEditorField(path: 'style', label: '样式 (style)', maxLines: 4),
    SourceEditorField(path: 'injectJs', label: '注入 JS (injectJs)', maxLines: 5),
    SourceEditorField(path: 'contentWhitelist', label: '白名单 (contentWhitelist)', maxLines: 3),
    SourceEditorField(path: 'contentBlacklist', label: '黑名单 (contentBlacklist)', maxLines: 3),
    SourceEditorField(path: 'shouldOverrideUrlLoading', label: 'URL 跳转拦截 (shouldOverrideUrlLoading)', maxLines: 5),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initialize() {
    final raw = widget.args.initialJson?.trim();
    if (raw != null && raw.isNotEmpty && raw != '{}') {
      _data.addAll(decodeSourceJson(raw));
    }
    final allFields = [..._basicFields, ..._listFields, ..._webViewFields];
    for (final field in allFields) {
      final rawValue = readPath(_data, field.path);
      String text;
      if (field.type == SourceFieldType.checkbox) {
        text = (rawValue == true).toString();
      } else {
        text = rawValue?.toString() ?? '';
      }
      _controllers[field.path] = TextEditingController(text: text);
    }
  }

  Future<void> _save() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      for (final entry in _controllers.entries) {
        final value = entry.value.text.trim();
        if (value.isEmpty) {
          writePath(_data, entry.key, null);
          continue;
        }
        final field = _findField(entry.key);
        if (field?.type == SourceFieldType.checkbox) {
          writePath(_data, entry.key, value == 'true');
        } else {
          writePath(_data, entry.key, value);
        }
      }
      final success = await context.read<RssManageProvider>().editSource(
            token,
            id: widget.args.id,
            json: encodePrettyJson(_data),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '保存成功' : '保存失败')),
      );
      if (success) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  SourceEditorField? _findField(String path) {
    for (final list in [_basicFields, _listFields, _webViewFields]) {
      for (final f in list) {
        if (f.path == path) return f;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '调试',
            onPressed: () {
              _saveCurrentToData();
              Navigator.pushNamed(
                context,
                AppRoutes.rssSourceDebug,
                arguments: {
                  'sourceUrl': (_data['sourceUrl'] ?? '').toString(),
                  'sourceName': (_data['sourceName'] ?? '订阅源').toString(),
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: '登录',
            onPressed: () {
              _saveCurrentToData();
              Navigator.pushNamed(
                context,
                AppRoutes.sourceLogin,
                arguments: SourceLoginPageArgs(
                  sourceUrl: (_data['sourceUrl'] ?? '').toString(),
                  sourceName: (_data['sourceName'] ?? '订阅源').toString(),
                  type: 'rssSource',
                  loginUi: (_data['loginUi'] ?? '').toString(),
                  loginUrl: (_data['loginUrl'] ?? '').toString(),
                  variableComment: (_data['variableComment'] ?? '').toString(),
                  header: (_data['header'] ?? '').toString(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _fields(_basicFields, showActions: true),
          _fields(_listFields),
          _fields(_webViewFields),
        ],
      ),
    );
  }

  void _saveCurrentToData() {
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        writePath(_data, entry.key, null);
        continue;
      }
      final field = _findField(entry.key);
      if (field?.type == SourceFieldType.checkbox) {
        writePath(_data, entry.key, value == 'true');
      } else {
        writePath(_data, entry.key, value);
      }
    }
  }

  Widget _fields(List<SourceEditorField> fields, {bool showActions = false}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...fields.map((field) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildField(field),
          );
        }),
        if (showActions) ...[
          const Divider(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  Widget _buildField(SourceEditorField field) {
    final controller = _controllers[field.path];

    switch (field.type) {
      case SourceFieldType.checkbox:
        final value = controller?.text == 'true';
        return CheckboxListTile(
          title: Text(field.label),
          value: value,
          onChanged: (v) {
            controller?.text = (v ?? false).toString();
            setState(() {});
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        );

      default:
        return TextField(
          controller: controller,
          maxLines: field.maxLines,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: field.maxLines > 1,
          ),
          style: TextStyle(
            fontFamily: field.maxLines > 2 ? 'monospace' : null,
            fontSize: field.maxLines > 2 ? 12 : null,
          ),
        );
    }
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.login, size: 18),
          label: const Text('登录'),
          onPressed: () {
            _saveCurrentToData();
            Navigator.pushNamed(
              context,
              AppRoutes.sourceLogin,
              arguments: SourceLoginPageArgs(
                sourceUrl: (_data['sourceUrl'] ?? '').toString(),
                sourceName: (_data['sourceName'] ?? '订阅源').toString(),
                type: 'rssSource',
                loginUi: (_data['loginUi'] ?? '').toString(),
                loginUrl: (_data['loginUrl'] ?? '').toString(),
                variableComment: (_data['variableComment'] ?? '').toString(),
                header: (_data['header'] ?? '').toString(),
              ),
            );
          },
        ),
        ActionChip(
          avatar: const Icon(Icons.bug_report, size: 18),
          label: const Text('调试'),
          onPressed: () {
            _saveCurrentToData();
            Navigator.pushNamed(
              context,
              AppRoutes.rssSourceDebug,
              arguments: {
                'sourceUrl': (_data['sourceUrl'] ?? '').toString(),
                'sourceName': (_data['sourceName'] ?? '订阅源').toString(),
              },
            );
          },
        ),
        ActionChip(
          avatar: const Icon(Icons.code, size: 18),
          label: const Text('变量'),
          onPressed: () {
            _showVariableDialog();
          },
        ),
      ],
    );
  }

  Future<void> _showVariableDialog() async {
    final token = context.read<UserProvider>().token ?? '';
    final sourceUrl = (_data['sourceUrl'] ?? '').toString();
    final api = ApiService.instance;

    String currentValue = '';
    try {
      final resp = await api.getRssVariable(token, sourceUrl);
      currentValue = resp['data']?.toString() ?? '';
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
            if ((_data['variableComment'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text((_data['variableComment'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
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
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('保存')),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await api.setRssVariable(token, sourceUrl, result);
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
}
