import 'dart:convert';
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
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        // 后端部分响应 content-type 为 text/plain，Dio 不自动 JSON 解码
        if (response.data is String) {
          try {
            response.data = jsonDecode(response.data as String);
          } catch (_) {
            // 非 JSON 字符串（如 appversion），保持原样
          }
        }
        handler.next(response);
      },
    ));
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
    final json = resp.data;
    if (json['isSuccess'] == true && json['data'] is List) {
      return (json['data'] as List).map((e) => BookSource.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Fallback: 直接获取书源列表（无缓存）
  Future<List<BookSource>> getBookSources(String accessToken) async {
    final resp = await _dio.get('/getBookSources', queryParameters: {
      'accessToken': accessToken,
    });
    final json = resp.data;
    if (json['isSuccess'] == true && json['data'] is List) {
      return (json['data'] as List).map((e) => BookSource.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<bool> getCanSource(String accessToken) async {
    final resp = await _dio.get('/getcansource', queryParameters: {
      'accessToken': accessToken,
    });
    final json = resp.data;
    // 后端有权限时返回 {"isSuccess": true}（无 data 字段）
    // 无权限时返回 {"isSuccess": false, "errorMsg": "CAN_NOT"}
    if (json['isSuccess'] == true) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> saveBookSources(String accessToken, String content) async {
    final resp = await _dio.post('/saveBookSources',
        queryParameters: {'accessToken': accessToken},
        data: content);
    return resp.data;
  }

  Future<Map<String, dynamic>> saveBookSourcesV2(
    String accessToken, {
    String? group,
    required String source,
    String? urls,
  }) async {
    final resp = await _dio.post('/saveBookSourcesv2', queryParameters: {
      'accessToken': accessToken,
      if (group != null) 'group': group,
      'source': source,
      if (urls != null) 'urls': urls,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> saveBookSource(String accessToken, String content) async {
    final resp = await _dio.post('/saveBookSource',
        queryParameters: {'accessToken': accessToken},
        data: content);
    return resp.data;
  }

  Future<Map<String, dynamic>> getbookSources(String accessToken, String id) async {
    final resp = await _dio.get('/getbookSources', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> editbookSources(String accessToken, {String? id, required String json}) async {
    final resp = await _dio.post('/editbookSources',
        queryParameters: {'accessToken': accessToken},
        data: {'id': id, 'json': json});
    return resp.data;
  }

  Future<Map<String, dynamic>> delbookSource(String accessToken, String id) async {
    final resp = await _dio.post('/delbookSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> delbookSources(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/delbookSources',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> stopbookSource(String accessToken, String id, {required int st}) async {
    final resp = await _dio.post('/stopbookSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'st': st,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> stopbookSources(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/stopbookSources',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> startbookSources(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/startbookSources',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> stopbookSourceExplores(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/stopbookSourceExplores',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> startbookSourceExplores(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/startbookSourceExplores',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> topSource(String accessToken, String id) async {
    final resp = await _dio.post('/topSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> bottomSource(String accessToken, String id) async {
    final resp = await _dio.post('/bottomSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> topallSource(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/topallSource',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> bottomallSource(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/bottomallSource',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> editsourcegroup(
    String accessToken, {
    required String st,
    String? group,
    required List<String> ids,
  }) async {
    final resp = await _dio.post('/editsourcegroup',
        queryParameters: {
          'accessToken': accessToken,
          'st': st,
          if (group != null) 'group': group,
        },
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> getbookSourcejson(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/getbookSourcejson',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> getSourcesloginui(
    String accessToken, {
    String? url,
    String? bookurl,
    String? chapter,
  }) async {
    final resp = await _dio.get('/getSourcesloginui', queryParameters: {
      'accessToken': accessToken,
      if (url != null) 'url': url,
      if (bookurl != null) 'bookurl': bookurl,
      if (chapter != null) 'chapter': chapter,
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
      'page': page.toString(),
    };
    if (md5 != null) params['md5'] = md5;
    final resp = await _dio.get('/getRssSourcessNew', queryParameters: params);
    final json = resp.data;
    if (json['isSuccess'] == true && json['data'] is List) {
      return (json['data'] as List).map((e) => RssSource.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Fallback: 直接获取RSS源列表（无缓存）
  Future<List<RssSource>> getRssSources(String accessToken) async {
    final raw = await getRssSourcesRaw(accessToken);
    final json = raw['json'];
    final data = json['data'];
    final sourcesList = data is Map ? data['sources'] : data;
    if (json['isSuccess'] == true && sourcesList is List) {
      return sourcesList.map((e) => RssSource.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getRssSourcesRaw(String accessToken) async {
    final resp = await _dio.get('/getRssSourcess', queryParameters: {
      'accessToken': accessToken,
    });
    final json = resp.data;
    final data = json['data'];
    final canEdit = data is Map ? data['can'] == true : false;
    return {
      'json': json,
      'canEdit': canEdit,
    };
  }

  Future<bool> getRssCanEdit(String accessToken) async {
    final raw = await getRssSourcesRaw(accessToken);
    return raw['canEdit'] == true;
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
    final articles = data is Map ? data['articles'] : data;
    if (articles is List) {
      return articles.map((e) => RssArticle.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getRssArticlesPage(
    String accessToken,
    String sourceId, {
    required String sortUrl,
    required String sortName,
    int page = 1,
  }) async {
    final resp = await _dio.get('/getArticles', queryParameters: {
      'accessToken': accessToken,
      'id': sourceId,
      'sortUrl': sortUrl,
      'sortName': sortName,
      'page': page,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getRssType(String accessToken, String id) async {
    final resp = await _dio.get('/getRssType', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<List<Map<String, String>>> getRsssortUrls(String accessToken, String id) async {
    final resp = await _dio.get('/getRsssortUrls', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    final data = resp.data['data'];
    if (data is List) {
      return data.map((e) {
        final item = e as Map;
        return {
          'sortName': item['sortName']?.toString() ?? '',
          'sortUrl': item['sortUrl']?.toString() ?? '',
        };
      }).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getRssContent(
    String accessToken, {
    required String id,
    required String article,
  }) async {
    final resp = await _dio.get('/getRssContent', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'article': article,
    });
    return resp.data;
  }

  Future<bool> rssshouldOverrideUrlLoading(
    String accessToken, {
    required String id,
    required String url,
  }) async {
    final resp = await _dio.get('/rssshouldOverrideUrlLoading', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'url': url,
    });
    final data = resp.data['data'];
    if (data is bool) return data;
    if (data is String) return data == 'true' || data == '1';
    if (data is num) return data != 0;
    return false;
  }

  Future<Map<String, dynamic>> getRssLoginInfo(String accessToken, String id) async {
    final resp = await _dio.get('/getRssLoginInfo', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> putRssLoginInfo(String accessToken, String id, String info) async {
    final resp = await _dio.post('/putRssLoginInfo', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'info': info,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> rssaction(String accessToken, String id, String action) async {
    final resp = await _dio.post('/rssaction', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'action': action,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getRssVariable(String accessToken, String id) async {
    final resp = await _dio.get('/getRssVariable', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> setRssVariable(String accessToken, String id, String info) async {
    final resp = await _dio.post('/setRssVariable', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'info': info,
    });
    return resp.data;
  }

  Future<String> fetchRemoteText(String url, {Map<String, String>? headers}) async {
    final resp = await Dio(BaseOptions(
      connectTimeout: 15000,
      receiveTimeout: 15000,
      responseType: ResponseType.plain,
      followRedirects: true,
      headers: headers,
    )).get<String>(url);
    return resp.data?.toString() ?? '';
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

  Future<Map<String, dynamic>> editRssSources(String accessToken, {String? id, required String json}) async {
    final resp = await _dio.post('/editRssSources',
        queryParameters: {'accessToken': accessToken},
        data: {'id': id, 'json': json});
    return resp.data;
  }

  Future<Map<String, dynamic>> delRssSource(String accessToken, String id) async {
    final resp = await _dio.post('/delRssSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> delRssSources(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/delRssSources',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> stopRssSource(String accessToken, String id, {required int st}) async {
    final resp = await _dio.post('/stopRssSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
      'st': st,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> startRssSources(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/startRssSources',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> stopRssSources(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/stopRssSources',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> topRssSource(String accessToken, String id) async {
    final resp = await _dio.post('/topRssSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> bottomRssSource(String accessToken, String id) async {
    final resp = await _dio.post('/bottomRssSource', queryParameters: {
      'accessToken': accessToken,
      'id': id,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> topallrssSource(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/topallrssSource',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> bottomallrssSource(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/bottomallrssSource',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> editrsssourcegroup(
    String accessToken, {
    required String st,
    required String group,
    required List<String> ids,
  }) async {
    final resp = await _dio.post('/editrsssourcegroup',
        queryParameters: {
          'accessToken': accessToken,
          'st': st,
          'group': group,
        },
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> getRssSourcejson(String accessToken, List<String> ids) async {
    final resp = await _dio.post('/getRssSourcejson',
        queryParameters: {'accessToken': accessToken},
        data: ids);
    return resp.data;
  }

  Future<Map<String, dynamic>> getRssSourcesloginui(String accessToken, String url) async {
    final resp = await _dio.get('/getRssSourcesloginui', queryParameters: {
      'accessToken': accessToken,
      'url': url,
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
