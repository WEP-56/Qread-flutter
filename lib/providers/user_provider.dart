import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  String? _token;
  String? _username;
  bool _loading = false;

  String? get token => _token;
  String? get username => _username;
  bool get loading => _loading;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final storage = await StorageService.instance;
    _token = storage.token;
    if (_token != null) {
      try {
        final info = await ApiService.instance.getUserInfo(_token!);
        if (info['isSuccess'] == true) {
          _username = info['data']?['userInfo']?['username'];
        } else {
          _token = null;
          await storage.removeToken();
        }
      } catch (_) {
        _token = null;
        await storage.removeToken();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    notifyListeners();

    try {
      final result = await ApiService.instance.login(username, password);
      if (result['isSuccess'] == true) {
        _token = result['data']?['accessToken'];
        _username = username;
        final storage = await StorageService.instance;
        await storage.setToken(_token!);
        _loading = false;
        notifyListeners();
        return true;
      }
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _username = null;
    final storage = await StorageService.instance;
    await storage.removeToken();
    notifyListeners();
  }
}
