import 'package:flutter/material.dart';

class RssSourcePage extends StatefulWidget {
  const RssSourcePage({Key? key}) : super(key: key);

  @override
  State<RssSourcePage> createState() => _RssSourcePageState();
}

class _RssSourcePageState extends State<RssSourcePage> {
  @override
  Widget build(BuildContext context) {
    // TODO: 实现RSS源管理
    return Scaffold(
      appBar: AppBar(title: const Text('订阅源管理')),
      body: const Center(child: Text('订阅源管理 - 开发中')),
    );
  }
}
