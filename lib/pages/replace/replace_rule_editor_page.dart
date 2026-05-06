import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/replace_rule.dart';
import '../../providers/replace_rule_provider.dart';
import '../../providers/user_provider.dart';

class ReplaceRuleEditorPageArgs {
  final String title;
  final ReplaceRule? initialRule;

  const ReplaceRuleEditorPageArgs({
    required this.title,
    this.initialRule,
  });
}

class ReplaceRuleEditorPage extends StatefulWidget {
  final ReplaceRuleEditorPageArgs args;

  const ReplaceRuleEditorPage({
    Key? key,
    required this.args,
  }) : super(key: key);

  @override
  State<ReplaceRuleEditorPage> createState() => _ReplaceRuleEditorPageState();
}

class _ReplaceRuleEditorPageState extends State<ReplaceRuleEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _groupController;
  late final TextEditingController _patternController;
  late final TextEditingController _replacementController;
  late final TextEditingController _scopeController;
  late final TextEditingController _excludeScopeController;
  late final TextEditingController _timeoutController;

  late bool _isRegex;
  late bool _scopeTitle;
  late bool _scopeContent;
  bool _saving = false;

  ReplaceRule get _initial => widget.args.initialRule ?? const ReplaceRule();

  @override
  void initState() {
    super.initState();
    final rule = _initial;
    _nameController = TextEditingController(text: rule.name);
    _groupController = TextEditingController(text: rule.groupName ?? '');
    _patternController = TextEditingController(text: rule.pattern);
    _replacementController = TextEditingController(text: rule.replacement);
    _scopeController = TextEditingController(text: rule.scope ?? '');
    _excludeScopeController =
        TextEditingController(text: rule.excludeScope ?? '');
    _timeoutController = TextEditingController(
      text: rule.timeoutMillisecond.toString(),
    );
    _isRegex = rule.isRegex;
    _scopeTitle = rule.scopeTitle;
    _scopeContent = rule.scopeContent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _patternController.dispose();
    _replacementController.dispose();
    _scopeController.dispose();
    _excludeScopeController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title),
        actions: [
          IconButton(
            tooltip: '复制 JSON',
            onPressed: _copyJson,
            icon: const Icon(Icons.content_copy_outlined),
          ),
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _field(
            controller: _nameController,
            label: '替换规则名称',
          ),
          _field(
            controller: _groupController,
            label: '分组',
          ),
          _field(
            controller: _patternController,
            label: '替换规则',
            minLines: 4,
            maxLines: 10,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _isRegex,
            title: const Text('使用正则表达式'),
            onChanged: (value) => setState(() => _isRegex = value ?? true),
          ),
          _field(
            controller: _replacementController,
            label: '替换为',
            hint: '支持 @js:',
            minLines: 2,
            maxLines: 8,
          ),
          const SizedBox(height: 12),
          Text(
            '作用于',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _scopeTitle,
                  title: const Text('标题'),
                  onChanged: (value) =>
                      setState(() => _scopeTitle = value ?? false),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _scopeContent,
                  title: const Text('正文'),
                  onChanged: (value) =>
                      setState(() => _scopeContent = value ?? true),
                ),
              ),
            ],
          ),
          _field(
            controller: _scopeController,
            label: '替换范围，选填书名或者书源 URL',
          ),
          _field(
            controller: _excludeScopeController,
            label: '排除范围，选填书名或者书源 URL',
          ),
          _field(
            controller: _timeoutController,
            label: '超时毫秒数',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  ReplaceRule _buildRule() {
    return _initial.copyWith(
      name: _nameController.text.trim(),
      groupName: _groupController.text.trim(),
      pattern: _patternController.text,
      replacement: _replacementController.text,
      scope: _scopeController.text.trim(),
      excludeScope: _excludeScopeController.text.trim(),
      isRegex: _isRegex,
      scopeTitle: _scopeTitle,
      scopeContent: _scopeContent,
      timeoutMillisecond: int.tryParse(_timeoutController.text.trim()) ?? 3000,
    );
  }

  Future<void> _copyJson() async {
    final json = const JsonEncoder.withIndent('  ').convert(
      _buildRule().toExportJson(),
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制规则 JSON')),
    );
  }

  Future<void> _save() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    final rule = _buildRule();
    if (rule.name.trim().isEmpty || rule.pattern.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('规则名称和替换规则不能为空')),
      );
      return;
    }
    if (!rule.scopeTitle && !rule.scopeContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和正文至少勾选一个')),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await context.read<ReplaceRuleProvider>().saveRule(token, rule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    final error = context.read<ReplaceRuleProvider>().error ?? '保存失败';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }
}
