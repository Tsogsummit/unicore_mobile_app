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

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final _api = UnicoreApi();
  String? _token;
  String? _email;
  String? _password;
  Map<String, dynamic>? _status;
  bool _restoring = true;
  bool _restoreRunning = false;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _token != null) _restore();
  }

  Future<void> _restore() async {
    if (_restoreRunning) return;
    _restoreRunning = true;
    if (mounted) {
      setState(() {
        _restoring = true;
        _restoreError = null;
      });
    }
    try {
      final token = await _api.restoreSession();
      if (!mounted) return;
      setState(() {
        _token = token;
        _email = _api.account;
      });
      if (token != null) await _loadStatus();
    } catch (error) {
      if (mounted) setState(() => _restoreError = error.toString());
    } finally {
      _restoreRunning = false;
      if (mounted) setState(() => _restoring = false);
    }
  }

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
    try {
      final status = await _api.getJson('/attendance/status', token: token);
      if (!mounted) return;
      setState(() {
        _status = status;
        _token = _api.currentToken;
      });
    } on ApiException catch (error) {
      if (error.status == 401) {
        await _logout();
        return;
      }
      rethrow;
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    await WatchSync.clearCredentials();
    if (!mounted) return;
    setState(() {
      _token = null;
      _email = null;
      _password = null;
      _status = null;
      _restoreError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoreError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Сервертэй холбогдох шаардлагатай'),
                  const SizedBox(height: 12),
                  Text(_restoreError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _restore,
                    child: const Text('Дахин шалгах'),
                  ),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Дахин нэвтрэх'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
