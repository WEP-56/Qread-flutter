import 'package:flutter/material.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({Key? key}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  @override
  Widget build(BuildContext context) {
    // TODO: 实现阅读器
    return Scaffold(
      appBar: AppBar(title: const Text('阅读')),
      body: const Center(child: Text('阅读器 - 开发中')),
    );
  }
}
