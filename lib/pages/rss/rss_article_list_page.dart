import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/rss_article.dart';
import '../../models/rss_source.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'rss_article_detail_page.dart';
import 'rss_web_page.dart';

class RssArticleListPageArgs {
  final RssSource source;

  const RssArticleListPageArgs({required this.source});
}

class RssArticleListPage extends StatefulWidget {
  final RssArticleListPageArgs args;

  const RssArticleListPage({Key? key, required this.args}) : super(key: key);

  @override
  State<RssArticleListPage> createState() => _RssArticleListPageState();
}

class _RssArticleListPageState extends State<RssArticleListPage> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _sorts = [];
  List<RssArticle> _articles = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  String? _nextToken;
  String _selectedSortName = '';
  String _selectedSortUrl = '';
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    if (_nextToken == null || _nextToken!.isEmpty) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadArticles(loadMore: true);
    }
  }

  Future<void> _init() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final typeResp = await ApiService.instance.getRssType(
        token,
        widget.args.source.sourceUrl ?? '',
      );
      final typeData = typeResp['data'] ?? {};
      final type = int.tryParse(typeData['type']?.toString() ?? '0') ?? 0;
      final directUrl = typeData['url']?.toString() ?? '';
      final enableJs = typeData['enableJs'] == true;
      final injectJs = typeData['js']?.toString();
      final header = _parseHeaders(typeData['header']?.toString());

      if (type == 1 && directUrl.isNotEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RssWebPage(
              args: RssWebPageArgs(
                title: widget.args.source.sourceName ?? '订阅源',
                url: directUrl,
                enableJs: enableJs,
                injectJs: injectJs,
                headers: header,
              ),
            ),
          ),
        );
        return;
      }

      List<Map<String, String>> sorts = [];

      try {
        sorts = await ApiService.instance.getRsssortUrls(
          token,
          widget.args.source.sourceUrl ?? '',
        );
      } catch (_) {}

      if (sorts.isEmpty) {
        sorts = [
          {
            'sortName': typeData['name']?.toString() ?? '默认',
            'sortUrl': typeData['url']?.toString() ?? (widget.args.source.sourceUrl ?? ''),
          }
        ];
      }

      if (!mounted) return;
      setState(() {
        _sorts = sorts;
        _selectedSortName = sorts.first['sortName'] ?? '';
        _selectedSortUrl = sorts.first['sortUrl'] ?? '';
      });

      await _loadArticles(refresh: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadArticles({bool refresh = false, bool loadMore = false}) async {
    final token = context.read<UserProvider>().token;
    if (token == null || _selectedSortUrl.isEmpty) return;

    final nextPage = refresh ? 1 : _page;
    if (!mounted) return;
    setState(() {
      if (refresh) {
        _loading = true;
        _error = null;
      } else if (loadMore) {
        _loadingMore = true;
      }
    });

    try {
      final response = await ApiService.instance.getRssArticlesPage(
        token,
        widget.args.source.sourceUrl ?? '',
        sortUrl: _selectedSortUrl,
        sortName: _selectedSortName,
        page: nextPage,
      );
      final data = response['data'] ?? {};
      final rawArticles = data['articles'];
      final articles = rawArticles is List
          ? rawArticles.map((e) => RssArticle.fromJson(e as Map<String, dynamic>)).toList()
          : <RssArticle>[];
      final next = data['next']?.toString();

      if (!mounted) return;
      setState(() {
        _articles = refresh ? articles : [..._articles, ...articles];
        _page = nextPage + 1;
        _nextToken = next;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _switchSort(Map<String, String> sort) {
    if (!mounted) return;
    setState(() {
      _selectedSortName = sort['sortName'] ?? '';
      _selectedSortUrl = sort['sortUrl'] ?? '';
      _articles = [];
      _page = 1;
      _nextToken = null;
    });
    _loadArticles(refresh: true);
  }

  Map<String, String> _parseHeaders(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    } catch (_) {}
    return const {};
  }

  void _openArticle(RssArticle article) {
    Navigator.pushNamed(
      context,
      AppRoutes.rssArticleDetail,
      arguments: RssArticleDetailPageArgs(
        source: widget.args.source,
        article: article,
        sortName: _selectedSortName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.source.sourceName ?? '订阅')),
      body: Column(
        children: [
          if (_sorts.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _sorts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final sort = _sorts[index];
                  final selected = sort['sortUrl'] == _selectedSortUrl;
                  return ChoiceChip(
                    label: Text(sort['sortName'] ?? ''),
                    selected: selected,
                    onSelected: (_) => _switchSort(sort),
                    visualDensity: VisualDensity.compact,
                    selectedColor: const Color(0xFF009688).withValues(alpha: 0.2),
                  );
                },
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _init, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_articles.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadArticles(refresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无文章')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadArticles(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _articles.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _articles.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final article = _articles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text(article.title ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((article.pubDate ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(article.pubDate!, style: const TextStyle(fontSize: 12)),
                    ),
                  if ((article.description ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        article.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openArticle(article),
            ),
          );
        },
      ),
    );
  }
}
