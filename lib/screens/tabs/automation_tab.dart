import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/widgets/buttons.dart';
import 'package:unicore_mobile_app/widgets/cards.dart';
import 'package:unicore_mobile_app/widgets/tiles.dart';

/// Tab describing the scheduled/automated attendance setup, plus logout.
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
