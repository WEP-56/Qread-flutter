import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入用户名和密码')));
      return;
    }

    final userProvider = context.read<UserProvider>();
    bool success;
    if (_isRegister) {
      try {
        final result = await ApiService.instance.register(username, password);
        success = result['isSuccess'] == true;
      } catch (e) {
        success = false;
      }
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
        setState(() => _isRegister = false);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册失败')));
        return;
      }
    } else {
      success = await userProvider.login(username, password);
      if (success && mounted) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? '注册' : '登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 72, color: Theme.of(context).primaryColor),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(_isRegister ? '注册' : '登录', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? '已有账号？去登录' : '没有账号？去注册'),
            ),
          ],
        ),
      ),
    );
  }
}
