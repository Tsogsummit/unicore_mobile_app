import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/models/activity_log.dart';
import 'package:unicore_mobile_app/theme/app_theme.dart';
import 'package:unicore_mobile_app/utils/formatters.dart';
import 'package:unicore_mobile_app/widgets/buttons.dart';
import 'package:unicore_mobile_app/widgets/cards.dart';
import 'package:unicore_mobile_app/widgets/tiles.dart';

/// The home dashboard: profile, metrics, attendance clock and activity log.
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
