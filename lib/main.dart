import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/screens/auth_gate.dart';
import 'package:unicore_mobile_app/theme/app_theme.dart';

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
