import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rss_manage_provider.dart';
import '../../providers/source_manage_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/adaptive_webview.dart';

class RssWebPageArgs {
  final String title;
  final String url;
  final bool enableJs;
  final String? injectJs;
  final Map<String, String> headers;

  const RssWebPageArgs({
    required this.title,
    required this.url,
    required this.enableJs,
    this.injectJs,
    this.headers = const {},
  });
}

class RssWebPage extends StatefulWidget {
  final RssWebPageArgs args;

  const RssWebPage({Key? key, required this.args}) : super(key: key);

  @override
  State<RssWebPage> createState() => _RssWebPageState();
}

class _RssWebPageState extends State<RssWebPage> {
  Future<void> _handleImportScheme(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    String? type;
    String? src;

    if (uri.scheme == 'yuedu') {
      type = uri.host.toLowerCase();
      src = uri.queryParameters['src'];
    } else if (uri.scheme == 'legado') {
      if (uri.host.toLowerCase() == 'import' && uri.pathSegments.isNotEmpty) {
        type = uri.pathSegments.first.toLowerCase();
        src = uri.queryParameters['src'];
      }
    }

    if (type == null || src == null || src.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法识别导入链接')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final token = context.read<UserProvider>().token;
    final sourceProvider = context.read<SourceManageProvider>();
    final rssProvider = context.read<RssManageProvider>();
    if (token == null) return;

    try {
      final content = await ApiService.instance.fetchRemoteText(src);
      if (content.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('导入内容为空')));
        return;
      }

      String? result;
      if (type == 'booksource') {
        result = await sourceProvider.importSources(token, content);
      } else if (type == 'rsssource') {
        result = await rssProvider.importSources(token, content);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('暂不支持导入类型: $type')),
        );
        return;
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(result ?? '导入失败')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.title)),
      body: AdaptiveWebView(
        url: widget.args.url,
        enableJs: widget.args.enableJs,
        injectJs: widget.args.injectJs,
        headers: widget.args.headers,
        onCustomScheme: _handleImportScheme,
      ),
    );
  }
}
