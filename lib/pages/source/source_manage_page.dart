import 'package:flutter/material.dart';

class SourceManagePage extends StatefulWidget {
  const SourceManagePage({Key? key}) : super(key: key);

  @override
  State<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends State<SourceManagePage> {
  @override
  Widget build(BuildContext context) {
    // TODO: 实现书源管理
    return Scaffold(
      appBar: AppBar(title: const Text('书源管理')),
      body: const Center(child: Text('书源管理 - 开发中')),
    );
  }
}
