import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/source_manage_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../login/source_login_page.dart';
import 'source_editor_support.dart';

class BookSourceEditorPageArgs {
  final String title;
  final String? id;
  final String? initialJson;

  const BookSourceEditorPageArgs({
    required this.title,
    this.id,
    this.initialJson,
  });
}

class BookSourceEditorPage extends StatefulWidget {
  final BookSourceEditorPageArgs args;

  const BookSourceEditorPage({Key? key, required this.args}) : super(key: key);

  @override
  State<BookSourceEditorPage> createState() => _BookSourceEditorPageState();
}

class _BookSourceEditorPageState extends State<BookSourceEditorPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, dynamic> _data = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  static const _tabs = ['基本', '搜索', '发现', '详情', '目录', '正文'];

  static const _basicFields = [
    SourceEditorField(path: 'bookSourceUrl', label: '源 URL (sourceUrl)'),
    SourceEditorField(path: 'bookSourceName', label: '源名称 (sourceName)'),
    SourceEditorField(path: 'bookSourceGroup', label: '源分组 (sourceGroup)'),
    SourceEditorField(path: 'bookSourceComment', label: '源注释 (sourceComment)', maxLines: 5),
    SourceEditorField(path: 'bookSourceType', label: '书籍类型', type: SourceFieldType.dropdown,
        options: ['小说', '听书', '漫画', '文件']),
    SourceEditorField(path: 'enabled', label: '启用', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'enabledExplore', label: '启用发现', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'enabledCookieJar', label: 'CookieJar', type: SourceFieldType.checkbox),
    SourceEditorField(path: 'loginUrl', label: '登录 URL (loginUrl)', maxLines: 5),
    SourceEditorField(path: 'loginUi', label: '登录 UI (loginUi)', maxLines: 6),
    SourceEditorField(path: 'loginCheckJs', label: '登录校验 JS (loginCheckJs)', maxLines: 5),
    SourceEditorField(path: 'coverDecodeJs', label: '封面解码 JS (coverDecodeJs)', maxLines: 5),
    SourceEditorField(path: 'bookUrlPattern', label: '书籍 URL 匹配 (bookUrlPattern)', maxLines: 3),
    SourceEditorField(path: 'header', label: '请求头 (header)', maxLines: 5),
    SourceEditorField(path: 'variableComment', label: '变量说明 (variableComment)', maxLines: 4),
    SourceEditorField(path: 'concurrentRate', label: '并发率 (concurrentRate)'),
    SourceEditorField(path: 'jsLib', label: 'jsLib', maxLines: 8),
  ];

  static const _searchFields = [
    SourceEditorField(path: 'searchUrl', label: '搜索 URL (searchUrl)', maxLines: 4),
    SourceEditorField(path: 'ruleSearch.checkKeyWord', label: '关键字检测 (checkKeyWord)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.bookList', label: '书籍列表规则 (bookList)', maxLines: 4),
    SourceEditorField(path: 'ruleSearch.name', label: '书名规则 (name)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.author', label: '作者规则 (author)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.kind', label: '分类规则 (kind)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.wordCount', label: '字数规则 (wordCount)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.lastChapter', label: '最新章节规则 (lastChapter)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.intro', label: '简介规则 (intro)', maxLines: 3),
    SourceEditorField(path: 'ruleSearch.coverUrl', label: '封面规则 (coverUrl)', maxLines: 2),
    SourceEditorField(path: 'ruleSearch.bookUrl', label: '详情 URL 规则 (bookUrl)', maxLines: 2),
  ];

  static const _exploreFields = [
    SourceEditorField(path: 'exploreUrl', label: '发现 URL (exploreUrl)', maxLines: 4),
    SourceEditorField(path: 'ruleExplore.bookList', label: '书籍列表规则 (bookList)', maxLines: 4),
    SourceEditorField(path: 'ruleExplore.name', label: '书名规则 (name)', maxLines: 2),
    SourceEditorField(path: 'ruleExplore.author', label: '作者规则 (author)', maxLines: 2),
    SourceEditorField(path: 'ruleExplore.kind', label: '分类规则 (kind)', maxLines: 2),
    SourceEditorField(path: 'ruleExplore.wordCount', label: '字数规则 (wordCount)', maxLines: 2),
    SourceEditorField(path: 'ruleExplore.lastChapter', label: '最新章节规则 (lastChapter)', maxLines: 2),
    SourceEditorField(path: 'ruleExplore.intro', label: '简介规则 (intro)', maxLines: 3),
    SourceEditorField(path: 'ruleExplore.coverUrl', label: '封面规则 (coverUrl)', maxLines: 2),
    SourceEditorField(path: 'ruleExplore.bookUrl', label: '详情 URL 规则 (bookUrl)', maxLines: 2),
  ];

  static const _infoFields = [
    SourceEditorField(path: 'ruleBookInfo.init', label: '详情初始化规则 (init)', maxLines: 4),
    SourceEditorField(path: 'ruleBookInfo.name', label: '书名规则 (name)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.author', label: '作者规则 (author)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.kind', label: '分类规则 (kind)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.wordCount', label: '字数规则 (wordCount)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.lastChapter', label: '最新章节规则 (lastChapter)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.intro', label: '简介规则 (intro)', maxLines: 3),
    SourceEditorField(path: 'ruleBookInfo.coverUrl', label: '封面规则 (coverUrl)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.tocUrl', label: '目录 URL 规则 (tocUrl)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.canReName', label: '可重命名 (canReName)', maxLines: 2),
    SourceEditorField(path: 'ruleBookInfo.downloadUrls', label: '下载地址规则 (downloadUrls)', maxLines: 3),
  ];

  static const _tocFields = [
    SourceEditorField(path: 'ruleToc.preUpdateJs', label: '预更新 JS (preUpdateJs)', maxLines: 4),
    SourceEditorField(path: 'ruleToc.chapterList', label: '章节列表规则 (chapterList)', maxLines: 4),
    SourceEditorField(path: 'ruleToc.chapterName', label: '章节名规则 (chapterName)', maxLines: 2),
    SourceEditorField(path: 'ruleToc.chapterUrl', label: '章节 URL 规则 (chapterUrl)', maxLines: 2),
    SourceEditorField(path: 'ruleToc.formatJs', label: '格式化 JS (formatJs)', maxLines: 4),
    SourceEditorField(path: 'ruleToc.isVolume', label: '卷标识规则 (isVolume)', maxLines: 2),
    SourceEditorField(path: 'ruleToc.updateTime', label: '更新时间规则 (updateTime)', maxLines: 2),
    SourceEditorField(path: 'ruleToc.isVip', label: 'VIP 规则 (isVip)', maxLines: 2),
    SourceEditorField(path: 'ruleToc.isPay', label: '付费规则 (isPay)', maxLines: 2),
    SourceEditorField(path: 'ruleToc.nextTocUrl', label: '下一页目录规则 (nextTocUrl)', maxLines: 2),
  ];

  static const _contentFields = [
    SourceEditorField(path: 'ruleContent.content', label: '正文规则 (content)', maxLines: 5),
    SourceEditorField(path: 'ruleContent.title', label: '标题规则 (title)', maxLines: 2),
    SourceEditorField(path: 'ruleContent.nextContentUrl', label: '下一页正文规则 (nextContentUrl)', maxLines: 2),
    SourceEditorField(path: 'ruleContent.webJs', label: 'WebView JS (webJs)', maxLines: 4),
    SourceEditorField(path: 'ruleContent.sourceRegex', label: 'sourceRegex', maxLines: 2),
    SourceEditorField(path: 'ruleContent.replaceRegex', label: 'replaceRegex', maxLines: 2),
    SourceEditorField(path: 'ruleContent.imageStyle', label: 'imageStyle', maxLines: 2),
    SourceEditorField(path: 'ruleContent.imageDecode', label: 'imageDecode', maxLines: 4),
    SourceEditorField(path: 'ruleContent.payAction', label: '付费动作 (payAction)', maxLines: 3),
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
    final allFields = [
      ..._basicFields,
      ..._searchFields,
      ..._exploreFields,
      ..._infoFields,
      ..._tocFields,
      ..._contentFields,
    ];
    for (final field in allFields) {
      final rawValue = readPath(_data, field.path);
      String text;
      if (field.type == SourceFieldType.checkbox) {
        text = (rawValue == true).toString();
      } else if (field.type == SourceFieldType.dropdown) {
        text = (rawValue is int ? rawValue : 0).toString();
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
        // Determine the field type to convert values correctly
        final field = _findField(entry.key);
        if (field?.type == SourceFieldType.checkbox) {
          writePath(_data, entry.key, value == 'true');
        } else if (field?.type == SourceFieldType.dropdown) {
          writePath(_data, entry.key, int.tryParse(value) ?? 0);
        } else {
          writePath(_data, entry.key, value);
        }
      }
      final success = await context.read<SourceManageProvider>().editSource(
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
    for (final list in [_basicFields, _searchFields, _exploreFields, _infoFields, _tocFields, _contentFields]) {
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
                AppRoutes.sourceDebug,
                arguments: {
                  'sourceUrl': (_data['bookSourceUrl'] ?? '').toString(),
                  'sourceName': (_data['bookSourceName'] ?? '书源').toString(),
                  'checkKeyWord': _getCheckKeyWord(),
                  'exploreUrl': (_data['exploreUrl'] ?? '').toString(),
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
                  sourceUrl: (_data['bookSourceUrl'] ?? '').toString(),
                  sourceName: (_data['bookSourceName'] ?? '书源').toString(),
                  type: 'bookSource',
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
          _fields(_searchFields),
          _fields(_exploreFields),
          _fields(_infoFields),
          _fields(_tocFields),
          _fields(_contentFields),
        ],
      ),
    );
  }

  String _getCheckKeyWord() {
    final raw = readPath(_data, 'ruleSearch.checkKeyWord');
    return raw?.toString() ?? '';
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
      } else if (field?.type == SourceFieldType.dropdown) {
        writePath(_data, entry.key, int.tryParse(value) ?? 0);
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

      case SourceFieldType.dropdown:
        final currentIndex = int.tryParse(controller?.text ?? '') ?? 0;
        return DropdownButtonFormField<int>(
          initialValue: (currentIndex >= 0 && currentIndex < (field.options?.length ?? 0))
              ? currentIndex
              : 0,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          items: field.options?.asMap().entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value));
          }).toList() ?? [],
          onChanged: (v) {
            controller?.text = (v ?? 0).toString();
            setState(() {});
          },
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
                sourceUrl: (_data['bookSourceUrl'] ?? '').toString(),
                sourceName: (_data['bookSourceName'] ?? '书源').toString(),
                type: 'bookSource',
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
              AppRoutes.sourceDebug,
              arguments: {
                'sourceUrl': (_data['bookSourceUrl'] ?? '').toString(),
                'sourceName': (_data['bookSourceName'] ?? '书源').toString(),
                'checkKeyWord': _getCheckKeyWord(),
                'exploreUrl': (_data['exploreUrl'] ?? '').toString(),
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
    final sourceUrl = (_data['bookSourceUrl'] ?? '').toString();
    final api = ApiService.instance;

    String currentValue = '';
    try {
      final resp = await api.getSourcesVariable(token, sourceUrl);
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
        await api.setSourcesVariable(token, sourceUrl, result);
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
