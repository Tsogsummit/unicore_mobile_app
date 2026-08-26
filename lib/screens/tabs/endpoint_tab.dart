import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/theme/app_theme.dart';
import 'package:unicore_mobile_app/widgets/cards.dart';
import 'package:unicore_mobile_app/widgets/tiles.dart';

/// Reference list of the mobile API endpoints, grouped by domain.
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
