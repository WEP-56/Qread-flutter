import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'config/constants.dart';
import 'providers/user_provider.dart';
import 'providers/bookshelf_provider.dart';
import 'providers/discover_provider.dart';
import 'providers/rss_provider.dart';
import 'providers/rss_manage_provider.dart';
import 'providers/reader_provider.dart';
import 'providers/replace_rule_provider.dart';
import 'providers/source_manage_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.instance;
  final savedBaseUrl = storage.baseUrl;
  if (savedBaseUrl != null && savedBaseUrl.isNotEmpty) {
    AppConstants.baseUrl = savedBaseUrl;
    ApiService.instance.setBaseUrl(savedBaseUrl);
  }
  runApp(const QreadApp());
}

class QreadApp extends StatelessWidget {
  const QreadApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..init()),
        ChangeNotifierProvider(create: (_) => BookshelfProvider()),
        ChangeNotifierProvider(create: (_) => DiscoverProvider()),
        ChangeNotifierProvider(create: (_) => RssProvider()),
        ChangeNotifierProvider(create: (_) => RssManageProvider()),
        ChangeNotifierProvider(create: (_) => ReaderProvider()),
        ChangeNotifierProvider(create: (_) => SourceManageProvider()),
        ChangeNotifierProvider(create: (_) => ReplaceRuleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
      ],
      child: const App(),
    );
  }
}
