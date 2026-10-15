import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/theme/app_theme.dart';

/// The UNiCORE logo mark + wordmark. [compact] shrinks it for app bars.
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
            gradient: const LinearGradient(
              colors: [Color(0xff2456e8), Color(0xff7ca9ff)],
            ),
          ),
          child: const Center(
            child: Text(
              'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNiCORE 4.0',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 22 : 28,
                letterSpacing: 0,
              ),
            ),
            Text(
              'Өдөр бүр хамтдаа',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
