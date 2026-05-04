import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/user_provider.dart';
import 'providers/bookshelf_provider.dart';
import 'providers/discover_provider.dart';
import 'providers/rss_provider.dart';
import 'providers/reader_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider(create: (_) => ReaderProvider()),
      ],
      child: const App(),
    );
  }
}
