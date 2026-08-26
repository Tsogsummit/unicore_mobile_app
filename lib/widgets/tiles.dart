import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/models/activity_log.dart';
import 'package:unicore_mobile_app/theme/app_theme.dart';
import 'package:unicore_mobile_app/utils/formatters.dart';

/// Bold section heading used inside cards.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900));
}

/// Small pill showing an API path.
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

/// Label/value row used in schedule and settings lists.
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

/// A single "METHOD  /path" row in the endpoints list.
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

/// Icon + title + subtitle row used in the feature preview lists.
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

/// Checkmarked step used in the automation instructions.
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

/// A single activity-history entry, color-coded by [ActivityLog.type].
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
