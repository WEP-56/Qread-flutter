import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/book.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/browsing_history_service.dart';
import '../../services/reading_stats_service.dart';
import '../../services/storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  ReadingStatsSnapshot _stats =
      const ReadingStatsSnapshot(totalSeconds: 0, todaySeconds: 0);
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final stats = await ReadingStatsService.instance.loadStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _statsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(userProvider, themeProvider, isDark),
          Transform.translate(
            offset: const Offset(0, -26),
            child: Column(
              children: [
                _buildCommonSection(),
                const SizedBox(height: 10),
                _buildAdvancedSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    UserProvider userProvider,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    final username = userProvider.username?.trim();
    final title =
        userProvider.isLoggedIn && username != null && username.isNotEmpty
            ? username.toUpperCase()
            : '立即登录';

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF63BBFF),
            Color(0xFF3395F2),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                tooltip: isDark ? '切换浅色模式' : '切换深色模式',
                onPressed: themeProvider.toggleLightDark,
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showUserManager(userProvider),
              child: Row(
                children: [
                  _ProfileAvatar(
                    username: userProvider.username,
                    loggedIn: userProvider.isLoggedIn,
                    size: 116,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            userProvider.isLoggedIn
                                ? _buildStatsText()
                                : '登录后端可多端同步',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonSection() {
    return _ProfilePanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.history_rounded,
              accent: const Color(0xFF66B6FF),
              title: '浏览历史',
              onTap: _showBrowsingHistorySheet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.tune_rounded,
              accent: const Color(0xFF58C06A),
              title: '常规设置',
              onTap: () => Navigator.pushNamed(context, '/settings/general'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.system_update_alt_rounded,
              accent: const Color(0xFFFFB84F),
              title: '检查更新',
              onTap: _showUpdatePlaceholder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return _ProfilePanel(
      child: Column(
        children: [
          _ProfileMenuTile(
            item: _ProfileMenuItem(
              icon: Icons.source_outlined,
              accent: const Color(0xFF66B6FF),
              title: '书源管理',
              onTap: () => Navigator.pushNamed(context, '/sourceManage'),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
            indent: 84,
            endIndent: 20,
          ),
          _ProfileMenuTile(
            item: _ProfileMenuItem(
              icon: Icons.cleaning_services_outlined,
              accent: const Color(0xFFAC7CFF),
              title: '替换净化',
              onTap: () => Navigator.pushNamed(context, '/replaceRules'),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
            indent: 84,
            endIndent: 20,
          ),
          _ProfileMenuTile(
            item: _ProfileMenuItem(
              icon: Icons.info_outline_rounded,
              accent: const Color(0xFF58C06A),
              title: '关于我们',
              subtitle: 'Qread v${AppConstants.appVersion}',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationLegalese: 'Qread',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildStatsText() {
    final today = _formatDuration(_stats.todaySeconds);
    final total = _formatDuration(_stats.totalSeconds);
    if (!_statsLoaded) {
      return '正在同步本地统计';
    }
    return '今日阅读 $today · 总阅读 $total';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    if (minutes < 60) {
      return '$minutes 分钟';
    }
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    if (remain == 0) {
      return '$hours 小时';
    }
    return '$hours 小时 $remain 分';
  }

  Future<void> _showUserManager(UserProvider userProvider) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: userProvider,
        child: const _UserManagerDialog(),
      ),
    );
    if (mounted) {
      _loadStats();
    }
  }

  Future<void> _showBrowsingHistorySheet() async {
    final history = await BrowsingHistoryService.instance.loadHistory();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '浏览历史',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${history.length} 本',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('还没有浏览历史'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _HistoryBookTile(book: history[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdatePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('检查更新功能稍后接入')),
    );
  }
}

class _UserManagerDialog extends StatefulWidget {
  const _UserManagerDialog();

  @override
  State<_UserManagerDialog> createState() => _UserManagerDialogState();
}

class _UserManagerDialogState extends State<_UserManagerDialog> {
  final TextEditingController _serverController =
      TextEditingController(text: AppConstants.baseUrl);
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showLoginForm = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final showLoginForm = !userProvider.isLoggedIn || _showLoginForm;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    showLoginForm ? '用户登录' : '用户管理',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 34),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(
              height: 28,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
            ),
            if (showLoginForm)
              _buildLoginForm(context, userProvider)
            else
              _buildUserCard(context, userProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              _ProfileAvatar(
                username: userProvider.username,
                loggedIn: true,
                size: 86,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProvider.username?.trim().toUpperCase() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '当前用户',
                        style: TextStyle(
                          color: Color(0xFF2F8CEB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppConstants.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.62),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _showLoginForm = true;
              _errorText = null;
            });
          },
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('登录新用户'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await userProvider.logout();
            if (!mounted) return;
            setState(() {
              _showLoginForm = true;
              _errorText = null;
            });
          },
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF564A)),
          label: const Text(
            '退出登录',
            style: TextStyle(
              color: Color(0xFFFF564A),
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(62),
            side: const BorderSide(color: Color(0xFFFF564A), width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _serverController,
          decoration: const InputDecoration(
            labelText: '后端地址',
            hintText: 'http://ip:port',
            prefixIcon: Icon(Icons.dns_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: '账号',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: '密码',
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          onSubmitted: (_) => _submitLogin(userProvider),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed:
              userProvider.loading ? null : () => _submitLogin(userProvider),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: userProvider.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  userProvider.isLoggedIn ? '切换账号' : '立即登录',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
        if (userProvider.isLoggedIn) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _showLoginForm = false;
                _errorText = null;
              });
            },
            child: const Text('返回当前用户'),
          ),
        ],
      ],
    );
  }

  Future<void> _submitLogin(UserProvider userProvider) async {
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = '请输入后端地址、账号和密码';
      });
      return;
    }

    AppConstants.baseUrl = server;
    ApiService.instance.setBaseUrl(server);
    final storage = await StorageService.instance;
    await storage.setBaseUrl(server);

    final success = await userProvider.login(username, password);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _errorText = '登录失败，请检查地址或账号密码';
      });
    }
  }
}

class _ProfilePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _ProfilePanel({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class _ProfileMenuItem {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}

class _ProfileMenuTile extends StatelessWidget {
  final _ProfileMenuItem item;

  const _ProfileMenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: item.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(item.icon, color: item.accent, size: 28),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      subtitle: item.subtitle == null ? null : Text(item.subtitle!),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: item.onTap,
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? username;
  final bool loggedIn;
  final double size;

  const _ProfileAvatar({
    required this.username,
    required this.loggedIn,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final letter = (username?.trim().isNotEmpty ?? false)
        ? username!.trim().substring(0, 1).toUpperCase()
        : '';

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.8),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFD),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: loggedIn
              ? Text(
                  letter.isEmpty ? 'Q' : letter,
                  style: TextStyle(
                    color: const Color(0xFF2F8CEB),
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Icon(
                  Icons.person_outline_rounded,
                  color: const Color(0xFF2F8CEB),
                  size: size * 0.38,
                ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 92,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent, size: 42),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBookTile extends StatelessWidget {
  final Book book;

  const _HistoryBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = book.customCoverUrl ?? book.coverUrl;
    final placeholder = Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: 30,
      ),
    );

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/reader', arguments: book);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              if (coverUrl != null && coverUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: ApiService.instance.getCoverProxyUrl(
                      coverUrl,
                      sourceUrl: book.origin,
                    ),
                    width: 72,
                    height: 96,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => placeholder,
                  ),
                )
              else
                placeholder,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((book.author ?? '').trim().isNotEmpty)
                      Text(
                        book.author!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.72),
                        ),
                      ),
                    if ((book.originName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '来源：${book.originName!.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
