import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/screens/dashboard_screen.dart';
import 'package:unicore_mobile_app/screens/login_screen.dart';
import 'package:unicore_mobile_app/services/unicore_api.dart';
import 'package:unicore_mobile_app/services/watch_sync.dart';

/// Top-level gate that shows the login screen until a token is obtained,
/// then swaps in the dashboard.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _api = UnicoreApi();
  String? _token;
  String? _email;
  String? _password;
  Map<String, dynamic>? _status;

  Future<void> _onLoggedIn(String token, String email, String password) async {
    setState(() {
      _token = token;
      _email = email;
      _password = password;
    });
    await _loadStatus();
  }

  Future<void> _loadStatus() async {
    final token = _token;
    if (token == null) return;
    final status = await _api.getJson('/attendance/status', token: token);
    if (!mounted) return;
    setState(() => _status = status);
  }

  void _logout() {
    WatchSync.clearCredentials();
    setState(() {
      _token = null;
      _email = null;
      _password = null;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return LoginScreen(api: _api, onLoggedIn: _onLoggedIn);
    }

    return DashboardScreen(
      api: _api,
      token: _token!,
      email: _email ?? 'user',
      password: _password ?? '',
      status: _status,
      onRefresh: _loadStatus,
      onLogout: _logout,
    );
  }
}
