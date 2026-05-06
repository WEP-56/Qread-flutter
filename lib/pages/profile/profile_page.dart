import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          return ListView(
            children: [
              // 用户信息卡片
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      userProvider.username?.substring(0, 1).toUpperCase() ??
                          '?',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  title: Text(
                    userProvider.isLoggedIn
                        ? userProvider.username ?? ''
                        : '未登录',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(userProvider.isLoggedIn ? '已登录' : '点击登录'),
                  trailing: userProvider.isLoggedIn
                      ? TextButton(
                          onPressed: () => userProvider.logout(),
                          child: const Text('退出',
                              style: TextStyle(color: Colors.red)),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: userProvider.isLoggedIn
                      ? null
                      : () => Navigator.pushNamed(context, '/login'),
                ),
              ),

              const SizedBox(height: 8),

              // 设置项
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('常规设置'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/settings/general'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.source),
                      title: const Text('书源管理'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/sourceManage'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.rss_feed),
                      title: const Text('订阅源管理'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/rssSource'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services),
                      title: const Text('替换规则'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/replaceRules'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 服务器设置
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns),
                      title: const Text('服务器地址'),
                      subtitle: Text(AppConstants.baseUrl,
                          style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showServerUrlDialog(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 关于
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('关于'),
                      subtitle: Text('v${AppConstants.appVersion}'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showServerUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: AppConstants.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('服务器地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://ip:port',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                AppConstants.baseUrl = url;
                ApiService.instance.setBaseUrl(url);
                final storage = await StorageService.instance;
                await storage.setBaseUrl(url);
                if (!mounted) return;
                setState(() {});
              }
              navigator.pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
