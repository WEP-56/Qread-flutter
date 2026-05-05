import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/source_manage_provider.dart';
import '../../providers/user_provider.dart';
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
  bool _enabled = true;
  bool _enabledExplore = true;
  bool _enabledCookieJar = false;
  int _bookSourceType = 0;
  bool _saving = false;

  static const _tabs = ['基本', '搜索', '发现', '详情', '目录', '正文'];

  static const _basicFields = [
    SourceEditorField(path: 'bookSourceUrl', label: '源 URL (sourceUrl)'),
    SourceEditorField(path: 'bookSourceName', label: '源名称 (sourceName)'),
    SourceEditorField(path: 'bookSourceGroup', label: '源分组 (sourceGroup)'),
    SourceEditorField(path: 'bookSourceComment', label: '源注释 (sourceComment)', maxLines: 5),
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
    _enabled = _data['enabled'] != false;
    _enabledExplore = _data['enabledExplore'] != false;
    _enabledCookieJar = _data['enabledCookieJar'] == true;
    _bookSourceType = _data['bookSourceType'] is int ? _data['bookSourceType'] as int : 0;
    final allFields = [
      ..._basicFields,
      ..._searchFields,
      ..._exploreFields,
      ..._infoFields,
      ..._tocFields,
      ..._contentFields,
    ];
    for (final field in allFields) {
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
      _data['enabledExplore'] = _enabledExplore;
      _data['enabledCookieJar'] = _enabledCookieJar;
      _data['bookSourceType'] = _bookSourceType;
      for (final entry in _controllers.entries) {
        final value = entry.value.text.trim();
        writePath(_data, entry.key, value.isEmpty ? null : value);
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
                  DropdownButton<int>(
                    value: _bookSourceType,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('小说')),
                      DropdownMenuItem(value: 1, child: Text('听书')),
                      DropdownMenuItem(value: 2, child: Text('漫画')),
                      DropdownMenuItem(value: 3, child: Text('文件')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _bookSourceType = value);
                    },
                  ),
                  _check('启用', _enabled, (v) => setState(() => _enabled = v)),
                  _check('发现', _enabledExplore, (v) => setState(() => _enabledExplore = v)),
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
                _fields(_searchFields),
                _fields(_exploreFields),
                _fields(_infoFields),
                _fields(_tocFields),
                _fields(_contentFields),
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
