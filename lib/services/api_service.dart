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
    // 后端通过 accessToken 查询参数认证，不需要 Bearer header
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
    // 后端没有独立的注册接口，注册也走 /login
    final resp = await _dio.post('/login', data: {
      'username': username,
      'password': password,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    final resp = await _dio.get('/getUserInfo', queryParameters: {
      'accessToken': accessToken,
    });
    return resp.data;
  }

  // ============ 书架 ============

  Future<Map<String, dynamic>> getBookshelfPage(String accessToken) async {
    final resp = await _dio.get('/getBookshelfPage', queryParameters: {
      'accessToken': accessToken,
    });
    return resp.data;
  }

  Future<List<Book>> getBookshelfNew(String accessToken, {String? md5, int page = 1}) async {
    final params = <String, dynamic>{
      'accessToken': accessToken,
      'page': page.toString(),
    };
    if (md5 != null) params['md5'] = md5;
    final resp = await _dio.get('/getBookshelfNew', queryParameters: params);
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveBookProgress(
    String accessToken, {
    String? url,
    String? title,
    int? index,
    double? pos,
    String? isnew,
  }) async {
    final resp = await _dio.post('/saveBookProgress', queryParameters: {
      'accessToken': accessToken,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (index != null) 'index': index,
      if (pos != null) 'pos': pos,
      if (isnew != null) 'isnew': isnew,
    });
    return resp.data;
  }

  Future<String> getBookread(String accessToken, String url) async {
    final resp = await _dio.get('/getBookread', queryParameters: {
      'accessToken': accessToken,
      'url': url,
    });
    return resp.data['data']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> addreadchapter(String accessToken, String readchapter, String url) async {
    final resp = await _dio.post('/addreadchapter', queryParameters: {
      'accessToken': accessToken,
      'readchapter': readchapter,
      'url': url,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteBooks(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/deleteBooks', data: ids);
    return resp.data;
  }

  // ============ 书籍 ============

  Future<Map<String, dynamic>> getBookInfo(String accessToken, String bookUrl, String sourceUrl) async {
    final resp = await _dio.get('/getBookinfo', queryParameters: {
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
      return data.map((e) => Chapter.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<Chapter>> getChapterListNew(
    String accessToken,
    String bookUrl,
    String sourceUrl, {
    String? bookname,
    int? useReplaceRule,
    int? needRefresh,
  }) async {
    final resp = await _dio.get('/getChapterListNew', queryParameters: {
      'accessToken': accessToken,
      'url': bookUrl,
      'bookSourceUrl': sourceUrl,
      if (bookname != null) 'bookname': bookname,
      if (useReplaceRule != null) 'useReplaceRule': useReplaceRule,
      if (needRefresh != null) 'needRefresh': needRefresh,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => Chapter.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<String> getBookContent(String accessToken, String bookUrl, int chapterIndex, String sourceUrl) async {
    final resp = await _dio.get('/getBookContent', queryParameters: {
      'accessToken': accessToken,
      'url': bookUrl,
      'index': chapterIndex,
      'source': sourceUrl,
    });
    return resp.data['data']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> getBookContentNew(
    String accessToken,
    String bookUrl,
    int chapterIndex,
    String sourceUrl, {
    int? type,
    String? bookname,
    int? useReplaceRule,
  }) async {
    final resp = await _dio.get('/getBookContentNew', queryParameters: {
      'accessToken': accessToken,
      'url': bookUrl,
      'index': chapterIndex,
      'bookSourceUrl': sourceUrl,
      if (type != null) 'type': type,
      if (bookname != null) 'bookname': bookname,
      if (useReplaceRule != null) 'useReplaceRule': useReplaceRule,
    });
    return resp.data['data'] ?? {};
  }

  // ============ 搜索 ============

  Future<List<SearchResult>> searchBook(String accessToken, String keyword, {String? bookSourceUrl, int page = 1}) async {
    final params = <String, dynamic>{
      'accessToken': accessToken,
      'key': keyword,
      'page': page,
    };
    if (bookSourceUrl != null) params['bookSourceUrl'] = bookSourceUrl;
    final resp = await _dio.get('/searchBook', queryParameters: params);
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => SearchResult.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ============ 发现 ============

  Future<Map<String, dynamic>> getExplore(String accessToken, String sourceUrl, String exploreUrl, {int page = 1}) async {
    final resp = await _dio.get('/exploreBook', queryParameters: {
      'accessToken': accessToken,
      'bookSourceUrl': sourceUrl,
      'page': page,
      'ruleFindUrl': exploreUrl,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getBookSourcesExploreUrl(String accessToken, String bookSourceUrl, {int need = 1}) async {
    final resp = await _dio.get('/getBookSourcesExploreUrl', queryParameters: {
      'accessToken': accessToken,
      'bookSourceUrl': bookSourceUrl,
      'need': need,
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

  Future<List<BookSource>> getBookSourcesNew(String accessToken, {String? md5, int page = 1}) async {
    final params = <String, dynamic>{
      'accessToken': accessToken,
      'page': page.toString(),
    };
    if (md5 != null) params['md5'] = md5;
    final resp = await _dio.get('/getBookSourcesNew', queryParameters: params);
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => BookSource.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveBookSources(String accessToken, String source) async {
    final resp = await _dio.post('/saveBookSources', queryParameters: {
      'accessToken': accessToken,
      'source': source,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteBookSources(String accessToken, List<String> urls) async {
    final resp = await _dio.post('/delbookSources', queryParameters: {
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

  Future<List<RssSource>> getRssSourcesNew(String accessToken, {String? md5, int page = 1}) async {
    final params = <String, dynamic>{
      'accessToken': accessToken,
      'page': page,
    };
    if (md5 != null) params['md5'] = md5;
    final resp = await _dio.get('/getRssSourcessNew', queryParameters: params);
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => RssSource.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<RssArticle>> getRssArticles(String accessToken, String sourceId, {String? sortUrl, int page = 1}) async {
    final params = <String, dynamic>{
      'accessToken': accessToken,
      'id': sourceId,
      'page': page,
    };
    if (sortUrl != null) params['sortUrl'] = sortUrl;
    final resp = await _dio.get('/getArticles', queryParameters: params);
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => RssArticle.fromJson(e as Map<String, dynamic>)).toList();
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
    final resp = await _dio.get('/getgroup', queryParameters: {
      'accessToken': accessToken,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => BookGroup.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<BookGroup>> getgroupNew(String accessToken, String md5) async {
    final resp = await _dio.get('/getgroupNew', queryParameters: {
      'accessToken': accessToken,
      'md5': md5,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) => BookGroup.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> addgroup(String accessToken, String name) async {
    final resp = await _dio.post('/addgroup', queryParameters: {
      'accessToken': accessToken,
      'name': name,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> delgroup(String accessToken, String name) async {
    final resp = await _dio.post('/delgroup', queryParameters: {
      'accessToken': accessToken,
      'name': name,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> editgroup(String accessToken, String oldname, String newname) async {
    final resp = await _dio.post('/editgroup', queryParameters: {
      'accessToken': accessToken,
      'oldname': oldname,
      'newname': newname,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> ordergroup(String accessToken, List<String> groups) async {
    final resp = await _dio.post('/ordergroup', queryParameters: {
      'accessToken': accessToken,
      'groups': groups,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> setgroup(String accessToken, {String? name, required String url}) async {
    final resp = await _dio.post('/setgroup', queryParameters: {
      'accessToken': accessToken,
      if (name != null) 'name': name,
      'url': url,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> setgroups(String accessToken, {String? name, required List<String> ids}) async {
    final resp = await _dio.post('/setgroups', queryParameters: {
      'accessToken': accessToken,
      if (name != null) 'name': name,
    }, data: ids);
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
    final resp = await _dio.post('/delReplaceRule', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  // ============ 书籍操作 ============

  Future<Map<String, dynamic>> saveBook(String accessToken, Book book, {int useReplaceRule = 0}) async {
    final resp = await _dio.post('/saveBook', queryParameters: {
      'accessToken': accessToken,
      'useReplaceRule': useReplaceRule,
    }, data: book.toJson());
    return resp.data;
  }

  Future<Map<String, dynamic>> deleteBook(String accessToken, Book book) async {
    final resp = await _dio.post('/deleteBook', queryParameters: {
      'accessToken': accessToken,
    }, data: book.toJson());
    return resp.data;
  }

  Future<Map<String, dynamic>> refreshBook(String accessToken, String bookUrl) async {
    final resp = await _dio.get('/refreshBook', queryParameters: {
      'accessToken': accessToken,
      'bookurl': bookUrl,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> changeBookType(String accessToken, String bookUrl, int type) async {
    final resp = await _dio.get('/changebooktype', queryParameters: {
      'accessToken': accessToken,
      'bookUrl': bookUrl,
      'type': type,
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
