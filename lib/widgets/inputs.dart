import 'package:flutter/material.dart';

import 'package:unicore_mobile_app/theme/app_theme.dart';

/// Bold label shown above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text));
}

/// Styled text input used throughout the login form.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
      ),
    );
  }
}

/// The "Password / QR / Passkey" segmented control (display only).
class SegmentedLoginModes extends StatelessWidget {
  const SegmentedLoginModes({super.key});

  @override
  Widget build(BuildContext context) {
    const items = ['Нууц үг', 'QR кодоор', 'Passkey'];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.blue : Colors.white,
                  border: Border(right: BorderSide(color: i == items.length - 1 ? Colors.transparent : AppColors.line)),
                ),
                child: Text(
                  items[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: i == 0 ? Colors.white : AppColors.text, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
