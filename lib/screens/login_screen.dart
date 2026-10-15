import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unicore_mobile_app/services/unicore_api.dart';
import 'package:unicore_mobile_app/services/watch_sync.dart';
import 'package:unicore_mobile_app/theme/app_theme.dart';
import 'package:unicore_mobile_app/widgets/branding.dart';
import 'package:unicore_mobile_app/widgets/buttons.dart';
import 'package:unicore_mobile_app/widgets/cards.dart';
import 'package:unicore_mobile_app/widgets/daily_word.dart';
import 'package:unicore_mobile_app/widgets/inputs.dart';
import 'package:unicore_mobile_app/widgets/tiles.dart';

/// Email/password login screen without preset or remembered credentials.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLoggedIn});

  final UnicoreApi api;
  final Future<void> Function(String token, String email, String password)
  onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String _loginStage = "";
  String? _loginError;
  final _stages = <String>[];
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  void _report(String stage) {
    if (!mounted) return;
    setState(() {
      _loginStage = stage;
      if (_stages.isEmpty || _stages.last != stage) _stages.add(stage);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'unicore_remember_me',
      'unicore_saved_email',
      'unicore_saved_password',
    ]) {
      await prefs.remove(key);
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('Имэйл болон нууц үгээ оруулна уу');
      return;
    }

    setState(() {
      _loading = true;
      _loginError = null;
      _stages.clear();
    });
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsedSeconds = timer.tick);
    });
    try {
      final token = await widget.api.login(
        email,
        password,
        onProgress: _report,
      );
      _report("Нэвтэрлээ. Watch-тай холбож байна…");
      // Mirror the signed-in credentials to the paired Apple Watch (iOS only,
      // best-effort) so the watch can run attendance on its own.
      await WatchSync.syncCredentials(email, password);
      await widget.onLoggedIn(token, email, password);
    } catch (error) {
      if (mounted) setState(() => _loginError = error.toString());
    } finally {
      _elapsedTimer?.cancel();

      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HeaderBrand(compact: false),
                    const SizedBox(height: 18),
                    const DailyWord(),
                    const SizedBox(height: 18),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'EN     MN',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Unicore 4.0-д тавтай морил',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 23,
                              height: 1.16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Олон байгууллагын ERP систем',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const FieldLabel('Имэйл / Нэвтрэх нэр / Утас'),
                          AppTextField(
                            controller: _email,
                            hint: 'Имэйл, нэвтрэх нэр эсвэл утас',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          const FieldLabel('Нууц үг'),
                          AppTextField(
                            controller: _password,
                            hint: 'Нууц үг',
                            obscureText: true,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Spacer(),
                              const ApiChip('/auth/login'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: 'Нэвтрэх',
                            loading: _loading,
                            onPressed: _login,
                          ),
                          if (_loading || _loginError != null) ...[
                            const SizedBox(height: 12),
                            if (_loading) const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _loading
                                    ? '$_loginStage ($_elapsedSeconds сек)'
                                    : 'Нэвтрэлт амжилтгүй',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_loading && _elapsedSeconds >= 10)
                              const Text(
                                'Хүсэлт үргэлжилж байна. Төхөөрөмж хайхад хугацаа шаардагдаж болно.',
                                textAlign: TextAlign.center,
                              ),
                            if (_loginError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _loginError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const Text(
                                'Холболт, нэвтрэх мэдээллээ шалгаад «Нэвтрэх» товчоор дахин оролдоно уу.',
                              ),
                            ],
                            if (_stages.length > 1)
                              ExpansionTile(
                                title: const Text('Явцын дэлгэрэнгүй'),
                                children: [
                                  for (final stage in _stages)
                                    ListTile(
                                      dense: true,
                                      leading: Icon(
                                        stage == _loginStage
                                            ? Icons.more_horiz
                                            : Icons.check,
                                      ),
                                      title: Text(stage),
                                    ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
