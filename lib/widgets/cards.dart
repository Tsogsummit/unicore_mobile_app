import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/theme/app_theme.dart';

/// Standard white rounded panel with a soft shadow.
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

/// A small labeled stat tile with a colored accent chip.
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
