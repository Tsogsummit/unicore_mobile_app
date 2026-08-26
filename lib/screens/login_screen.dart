import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unicore_mobile_app/services/unicore_api.dart';
import 'package:unicore_mobile_app/services/watch_sync.dart';
import 'package:unicore_mobile_app/theme/app_theme.dart';
import 'package:unicore_mobile_app/widgets/branding.dart';
import 'package:unicore_mobile_app/widgets/buttons.dart';
import 'package:unicore_mobile_app/widgets/cards.dart';
import 'package:unicore_mobile_app/widgets/inputs.dart';
import 'package:unicore_mobile_app/widgets/tiles.dart';

/// Email/password login screen with optional "remember me" persistence.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLoggedIn});

  final UnicoreApi api;
  final Future<void> Function(String token, String email, String password) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRemember = prefs.getBool('unicore_remember_me') ?? false;
      if (savedRemember) {
        final savedEmail = prefs.getString('unicore_saved_email') ?? '';
        final savedPassword = prefs.getString('unicore_saved_password') ?? '';
        if (mounted) {
          setState(() {
            _email.text = savedEmail;
            _password.text = savedPassword;
            _remember = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCredentials(String email, String password, bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (remember) {
        await prefs.setBool('unicore_remember_me', true);
        await prefs.setString('unicore_saved_email', email);
        await prefs.setString('unicore_saved_password', password);
      } else {
        await prefs.setBool('unicore_remember_me', false);
        await prefs.remove('unicore_saved_email');
        await prefs.remove('unicore_saved_password');
      }
    } catch (_) {}
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('Имэйл болон нууц үгээ оруулна уу');
      return;
    }

    setState(() => _loading = true);
    try {
      final token = await widget.api.login(email, password);
      await _saveCredentials(email, password, _remember);
      // Mirror the signed-in credentials to the paired Apple Watch (iOS only,
      // best-effort) so the watch can run attendance on its own.
      await WatchSync.syncCredentials(email, password);
      await widget.onLoggedIn(token, email, password);
    } catch (error) {
      _toast(error.toString());
    } finally {
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
                    const SizedBox(height: 22),
                    const HeroPreview(),
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
                            'Unicore 3.0-д тавтай морил',
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
                            style: TextStyle(color: AppColors.muted, fontSize: 15),
                          ),
                          const SizedBox(height: 20),
                          const SegmentedLoginModes(),
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
                              Checkbox(
                                value: _remember,
                                activeColor: AppColors.blue,
                                onChanged: (value) => setState(() {
                                  _remember = value ?? false;
                                }),
                              ),
                              const Text(
                                'Намайг сана',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
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
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(child: StoreButton(icon: CupertinoIcons.play_arrow_solid, label: 'Google Play')),
                        SizedBox(width: 10),
                        Expanded(child: StoreButton(icon: Icons.apple, label: 'App Store')),
                      ],
                    ),
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
