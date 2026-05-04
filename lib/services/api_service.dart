import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../models/rss_source.dart';
import '../models/rss_article.dart';
import '../models/search_result.dart';
import '../models/chapter.dart';
import '../models/book_group.dart';
import '../models/replace_rule.dart';

class ApiService {
  static ApiService? _instance;
  late Dio _dio;

  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBase,
      connectTimeout: 15000,
      receiveTimeout: 15000,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ));
    _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  static ApiService get instance => _instance ??= ApiService._();

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void setBaseUrl(String url) {
    AppConstants.baseUrl = url;
    _dio.options.baseUrl = AppConstants.apiBase;
  }

  // ============ 用户 ============

  Future<Map<String, dynamic>> login(String username, String password) async {
    final resp = await _dio.post('/login', data: {
      'username': username,
      'password': password,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> register(String username, String password) async {
    final resp = await _dio.post('/register', data: {
      'username': username,
      'password': password,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    final resp = await _dio.get('/getuserinfo', queryParameters: {
      'accessToken': accessToken,
    });
    return resp.data;
  }

  // ============ 书架 ============

  Future<Map<String, dynamic>> getBookshelfPage(String accessToken, {int page = 1}) async {
    final resp = await _dio.get('/getBookshelfsPage', queryParameters: {
      'accessToken': accessToken,
    });
    return resp.data;
  }

  Future<List<Book>> getBookshelfNew(String accessToken, {int page = 1, int size = AppConstants.pageSize}) async {
    final resp = await _dio.get('/getBookshelfsNew', queryParameters: {
      'accessToken': accessToken,
      'page': page,
      'size': size,
    });
    return (resp.data['data'] as List?)?.map((e) => Book.fromJson(e)).toList() ?? [];
  }

  Future<Map<String, dynamic>> saveBookProgress(String accessToken, Book book) async {
    final resp = await _dio.post('/saveBookProgress', queryParameters: {
      'accessToken': accessToken,
      'name': book.name,
      'author': book.author,
      'durChapterIndex': book.durChapterIndex ?? 0,
      'durChapterPos': book.durChapterPos ?? 0,
      'durChapterTitle': book.durChapterTitle ?? '',
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteBooks(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/deleteBooks', queryParameters: {
      'accessToken': accessToken,
      'ids': ids.join(','),
    });
    return resp.data;
  }

  // ============ 书籍 ============

  Future<Map<String, dynamic>> getBookInfo(String accessToken, String bookUrl, String sourceUrl) async {
    final resp = await _dio.get('/getBookInfo', queryParameters: {
      'accessToken': accessToken,
      'url': bookUrl,
      'source': sourceUrl,
    });
    return resp.data;
  }

  Future<List<Chapter>> getChapterList(String accessToken, String bookUrl, String sourceUrl) async {
    final resp = await _dio.get('/getChapterList', queryParameters: {
      'accessToken': accessToken,
      'url': bookUrl,
      'source': sourceUrl,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => Chapter.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getBookContent(String accessToken, String bookUrl, int chapterIndex, String sourceUrl) async {
    final resp = await _dio.get('/getBookContent', queryParameters: {
      'accessToken': accessToken,
      'url': bookUrl,
      'index': chapterIndex,
      'source': sourceUrl,
    });
    return resp.data;
  }

  // ============ 搜索 ============

  Future<List<SearchResult>> searchBook(String accessToken, String keyword, {int page = 1}) async {
    final resp = await _dio.get('/searchBook', queryParameters: {
      'accessToken': accessToken,
      'key': keyword,
      'page': page,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => SearchResult.fromJson(e)).toList();
    }
    return [];
  }

  // ============ 发现 ============

  Future<Map<String, dynamic>> getExplore(String accessToken, String sourceUrl, String exploreUrl, {int page = 1}) async {
    final resp = await _dio.get('/getExplore', queryParameters: {
      'accessToken': accessToken,
      'source': sourceUrl,
      'url': exploreUrl,
      'page': page,
    });
    return resp.data;
  }

  // ============ 书源 ============

  Future<Map<String, dynamic>> getBookSourcesPage(String accessToken) async {
    final resp = await _dio.get('/getBookSourcesPage', queryParameters: {
      'accessToken': accessToken,
    });
    return resp.data;
  }

  Future<List<BookSource>> getBookSourcesNew(String accessToken, {int page = 1, int size = AppConstants.pageSize}) async {
    final resp = await _dio.get('/getBookSourcesNew', queryParameters: {
      'accessToken': accessToken,
      'page': page,
      'size': size,
    });
    return (resp.data['data'] as List?)?.map((e) => BookSource.fromJson(e)).toList() ?? [];
  }

  Future<Map<String, dynamic>> saveBookSources(String accessToken, String source) async {
    final resp = await _dio.post('/saveBookSources', queryParameters: {
      'accessToken': accessToken,
      'source': source,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteBookSources(String accessToken, List<String> urls) async {
    final resp = await _dio.post('/deleteBookSources', queryParameters: {
      'accessToken': accessToken,
      'urls': urls.join(','),
    });
    return resp.data;
  }

  // ============ RSS ============

  Future<Map<String, dynamic>> getRssSourcesPage(String accessToken) async {
    final resp = await _dio.get('/getRssSourcessPage', queryParameters: {
      'accessToken': accessToken,
    });
    return resp.data;
  }

  Future<List<RssSource>> getRssSourcesNew(String accessToken, {int page = 1, int size = AppConstants.pageSize}) async {
    final resp = await _dio.get('/getRssSourcessNew', queryParameters: {
      'accessToken': accessToken,
      'page': page,
      'size': size,
    });
    return (resp.data['data'] as List?)?.map((e) => RssSource.fromJson(e)).toList() ?? [];
  }

  Future<List<RssArticle>> getRssArticles(String accessToken, String sourceUrl, {int page = 1}) async {
    final resp = await _dio.get('/getRssArticles', queryParameters: {
      'accessToken': accessToken,
      'source': sourceUrl,
      'page': page,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => RssArticle.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveRssSources(String accessToken, {String? source, String? urls}) async {
    final resp = await _dio.post('/saveRssSources', queryParameters: {
      'accessToken': accessToken,
      if (source != null) 'source': source,
      if (urls != null) 'urls': urls,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteRssSources(String accessToken, List<String> urls) async {
    final resp = await _dio.post('/delRssSources', queryParameters: {
      'accessToken': accessToken,
      'urls': urls.join(','),
    });
    return resp.data;
  }

  // ============ 分组 ============

  Future<List<BookGroup>> getBookGroups(String accessToken) async {
    final resp = await _dio.get('/getBookGroups', queryParameters: {
      'accessToken': accessToken,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => BookGroup.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveBookGroup(String accessToken, String name, {int? groupId}) async {
    final resp = await _dio.post('/saveBookGroup', queryParameters: {
      'accessToken': accessToken,
      'name': name,
      if (groupId != null) 'groupId': groupId,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteBookGroup(String accessToken, int groupId) async {
    final resp = await _dio.post('/deleteBookGroup', queryParameters: {
      'accessToken': accessToken,
      'groupId': groupId,
    });
    return resp.data;
  }

  // ============ 替换规则 ============

  Future<List<ReplaceRule>> getReplaceRules(String accessToken) async {
    final resp = await _dio.get('/getReplaceRules', queryParameters: {
      'accessToken': accessToken,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => ReplaceRule.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveReplaceRule(String accessToken, ReplaceRule rule) async {
    final resp = await _dio.post('/saveReplaceRule', queryParameters: {
      'accessToken': accessToken,
      'id': rule.id,
      'group': rule.group,
      'name': rule.name,
      'replaceRegex': rule.replaceRegex,
      'replacement': rule.replacement,
      'scope': rule.scope,
      'isEnabled': rule.isEnabled == true ? 1 : 0,
      'isRegex': rule.isRegex == true ? 1 : 0,
      'sortOrder': rule.sortOrder,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteReplaceRule(String accessToken, int id) async {
    final resp = await _dio.post('/deleteReplaceRule', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  // ============ 书籍操作 ============

  Future<Map<String, dynamic>> saveBook(String accessToken, Book book) async {
    final resp = await _dio.post('/saveBook', queryParameters: {
      'accessToken': accessToken,
      'bookUrl': book.bookUrl,
      'name': book.name,
      'author': book.author,
      'coverUrl': book.coverUrl,
      'intro': book.intro,
      'tocUrl': book.tocUrl,
      'origin': book.origin,
      'originName': book.originName,
      'type': book.type ?? 0,
      'group': book.group ?? 0,
    });
    return resp.data;
  }

  // ============ 封面代理 ============

  String getCoverProxyUrl(String? coverUrl, {String? sourceUrl}) {
    if (coverUrl == null || coverUrl.isEmpty) return '';
    final params = <String, String>{'url': coverUrl};
    if (sourceUrl != null) params['source'] = sourceUrl;
    return '${AppConstants.apiBase}/proxypng?${_encodeParams(params)}';
  }

  String _encodeParams(Map<String, String> params) {
    return params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  }
}
