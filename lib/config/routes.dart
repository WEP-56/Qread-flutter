import 'package:flutter/material.dart';
import '../pages/bookshelf/bookshelf_page.dart';
import '../pages/discover/discover_page.dart';
import '../pages/rss/rss_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/replace/replace_rule_editor_page.dart';
import '../pages/replace/replace_rule_page.dart';
import '../pages/reader/reader_page.dart';
import '../pages/search/search_page.dart';
import '../pages/settings/general_settings_page.dart';
import '../pages/login/login_page.dart';
import '../pages/login/source_login_page.dart';
import '../pages/login/webview_login_page.dart';
import '../pages/source/source_manage_page.dart';
import '../pages/source/book_source_editor_page.dart';
import '../pages/source/book_source_debug_page.dart';
import '../pages/rss/rss_source_page.dart';
import '../pages/rss/rss_source_editor_page.dart';
import '../pages/rss/rss_source_debug_page.dart';
import '../pages/discover/explore_books_page.dart';
import '../pages/rss/rss_article_list_page.dart';
import '../pages/rss/rss_article_detail_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String reader = '/reader';
  static const String search = '/search';
  static const String sourceManage = '/sourceManage';
  static const String bookSourceEditor = '/source/editor';
  static const String sourceLogin = '/source/login';
  static const String sourceWebLogin = '/source/weblogin';
  static const String sourceDebug = '/source/debug';
  static const String rssSource = '/rssSource';
  static const String rssSourceEditor = '/rss/source/editor';
  static const String rssSourceDebug = '/rss/source/debug';
  static const String replaceRules = '/replaceRules';
  static const String replaceRuleEditor = '/replaceRules/editor';
  static const String generalSettings = '/settings/general';
  static const String discoverExplore = '/discover/explore';
  static const String rssArticles = '/rss/articles';
  static const String rssArticleDetail = '/rss/article';

  static final Map<String, WidgetBuilder> routes = {
    home: (_) => const HomePage(),
    login: (_) => const LoginPage(),
    search: (_) => const SearchPage(),
    generalSettings: (_) => const GeneralSettingsPage(),
    sourceManage: (_) => const SourceManagePage(),
    rssSource: (_) => const RssSourcePage(),
    replaceRules: (_) => const ReplaceRulePage(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == reader) {
      return MaterialPageRoute(
        settings: settings, // pass settings to preserve arguments
        builder: (_) => const ReaderPage(),
      );
    }
    if (settings.name == discoverExplore) {
      final args = settings.arguments as ExploreBooksPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => ExploreBooksPage(args: args),
      );
    }
    if (settings.name == bookSourceEditor) {
      final args = settings.arguments as BookSourceEditorPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => BookSourceEditorPage(args: args),
      );
    }
    if (settings.name == rssArticles) {
      final args = settings.arguments as RssArticleListPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => RssArticleListPage(args: args),
      );
    }
    if (settings.name == rssSourceEditor) {
      final args = settings.arguments as RssSourceEditorPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => RssSourceEditorPage(args: args),
      );
    }
    if (settings.name == rssArticleDetail) {
      final args = settings.arguments as RssArticleDetailPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => RssArticleDetailPage(args: args),
      );
    }
    if (settings.name == sourceLogin) {
      final args = settings.arguments as SourceLoginPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => SourceLoginPage(args: args),
      );
    }
    if (settings.name == sourceWebLogin) {
      final args = settings.arguments as WebViewLoginPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => WebViewLoginPage(args: args),
      );
    }
    if (settings.name == sourceDebug) {
      final args = settings.arguments as Map<String, String>;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => BookSourceDebugPage(args: args),
      );
    }
    if (settings.name == rssSourceDebug) {
      final args = settings.arguments as Map<String, String>;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => RssSourceDebugPage(args: args),
      );
    }
    if (settings.name == replaceRuleEditor) {
      final args = settings.arguments as ReplaceRuleEditorPageArgs;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => ReplaceRuleEditorPage(args: args),
      );
    }
    return null;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    BookshelfPage(),
    DiscoverPage(),
    RssPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: '书架',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rss_feed_outlined),
            activeIcon: Icon(Icons.rss_feed),
            label: '订阅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
