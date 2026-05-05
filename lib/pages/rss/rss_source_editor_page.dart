import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rss_manage_provider.dart';
import '../../providers/user_provider.dart';
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
  bool _enabled = true;
  bool _singleUrl = false;
  bool _enabledCookieJar = false;
  bool _saving = false;

  static const _tabs = ['基本', '列表', 'WEBVIEW'];

  static const _basicFields = [
    SourceEditorField(path: 'sourceName', label: '源名称 (sourceName)'),
    SourceEditorField(path: 'sourceUrl', label: '源 URL (sourceUrl)'),
    SourceEditorField(path: 'sourceIcon', label: '图标 (sourceIcon)'),
    SourceEditorField(path: 'sourceGroup', label: '源分组 (sourceGroup)'),
    SourceEditorField(path: 'sourceComment', label: '源注释 (sourceComment)', maxLines: 4),
    SourceEditorField(path: 'sortUrl', label: '分类 URL (sortUrl)', maxLines: 3),
    SourceEditorField(path: 'loginUrl', label: '登录 URL (loginUrl)', maxLines: 5),
    SourceEditorField(path: 'loginUi', label: '登录 UI (loginUi)', maxLines: 6),
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
    _enabled = _data['enabled'] != false;
    _singleUrl = _data['singleUrl'] == true;
    _enabledCookieJar = _data['enabledCookieJar'] == true;
    for (final field in [..._basicFields, ..._listFields, ..._webViewFields]) {
      _controllers[field.path] = TextEditingController(
        text: readPath(_data, field.path)?.toString() ?? '',
      );
    }
  }

  Future<void> _save() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      _data['enabled'] = _enabled;
      _data['singleUrl'] = _singleUrl;
      _data['enabledCookieJar'] = _enabledCookieJar;
      for (final entry in _controllers.entries) {
        final value = entry.value.text.trim();
        writePath(_data, entry.key, value.isEmpty ? null : value);
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
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _check('启用', _enabled, (v) => setState(() => _enabled = v)),
                  _check('单 URL', _singleUrl, (v) => setState(() => _singleUrl = v)),
                  _check('CookieJar', _enabledCookieJar, (v) => setState(() => _enabledCookieJar = v)),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _fields(_basicFields),
                _fields(_listFields),
                _fields(_webViewFields),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
          Text(label),
        ],
      ),
    );
  }

  Widget _fields(List<SourceEditorField> fields) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: fields.map((field) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _controllers[field.path],
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
          ),
        );
      }).toList(),
    );
  }
}
