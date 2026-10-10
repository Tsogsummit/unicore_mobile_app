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
        const Text(
          'Автомат бүртгэл',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Серверийн автомат бүртгэл'),
              StepText(
                '13.214.2.6 сервер дээр ажиллана. Утас нээлттэй байх шаардлагагүй.',
              ),
              StepText(
                'Серверийн тохируулсан хэрэглэгчид Лхагва–Баасан ажиллана.',
              ),
              StepText('Ирэх 07:30–07:45, явах 16:15–16:30 дотор цаг сонгоно.'),
              StepText(
                'Service /auth/login -> /auth/select-tenant -> /attendance/check-in эсвэл check-out дарааллаар ажиллана.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Asia/Ulaanbaatar · Лхагва–Баасан'),
              ScheduleRow(label: 'Ирэх', value: '07:30–07:45 UTC+8'),
              ScheduleRow(label: 'Явах', value: '16:15–16:30 UTC+8'),
              ScheduleRow(label: 'Coordinates', value: 'Random within 100m'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Гарах', onPressed: onLogout),
      ],
    );
  }
}
