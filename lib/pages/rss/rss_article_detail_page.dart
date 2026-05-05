import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/rss_article.dart';
import '../../models/rss_source.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/adaptive_webview.dart';

class RssArticleDetailPageArgs {
  final RssSource source;
  final RssArticle article;
  final String sortName;

  const RssArticleDetailPageArgs({
    required this.source,
    required this.article,
    required this.sortName,
  });
}

class RssArticleDetailPage extends StatefulWidget {
  final RssArticleDetailPageArgs args;

  const RssArticleDetailPage({Key? key, required this.args}) : super(key: key);

  @override
  State<RssArticleDetailPage> createState() => _RssArticleDetailPageState();
}

class _RssArticleDetailPageState extends State<RssArticleDetailPage> {
  bool _loading = true;
  String? _error;
  String? _htmlUrl;
  String? _injectJs;
  bool _enableJs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
  }

  Future<void> _loadContent() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiService.instance.getRssContent(
        token,
        id: widget.args.source.sourceUrl ?? '',
        article: jsonEncode(widget.args.article.toJson()),
      );
      final data = response['data'] ?? {};
      final id = data['id']?.toString() ?? '';
      _injectJs = data['js']?.toString();
      _enableJs = data['enableJs'] == true;
      _htmlUrl = '${AppConstants.apiBase}/getRssContenthtml?id=$id';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openOriginal() async {
    final link = widget.args.article.link;
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.article.title ?? '文章详情'),
        actions: [
          if ((widget.args.article.link ?? '').isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '打开原文',
              onPressed: _openOriginal,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadContent, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_htmlUrl == null || _htmlUrl!.isEmpty) {
      return const Center(child: Text('正文为空'));
    }

    return AdaptiveWebView(
      url: _htmlUrl!,
      enableJs: _enableJs,
      injectJs: _injectJs,
    );
  }
}
