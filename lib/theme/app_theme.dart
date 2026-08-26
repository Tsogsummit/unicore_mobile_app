import 'package:flutter/material.dart';

/// Centralized color palette for the app.
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

/// Soft elevation shadow used across cards and panels.
List<BoxShadow> get softShadow => [
      BoxShadow(
        color: const Color(0xff1f2d4e).withValues(alpha: .08),
        blurRadius: 26,
        offset: const Offset(0, 12),
      ),
    ];
