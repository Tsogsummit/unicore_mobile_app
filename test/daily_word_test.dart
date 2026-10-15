import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unicore_mobile_app/widgets/daily_word.dart';

void main() {
  testWidgets('shows English above Mongolian without a provider button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyWord(
            clientFactory: () => MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'date': '2026-10-14',
                  'english': 'Keep learning.',
                  'mongolian': 'Үргэлж суралцаарай.',
                  'automatic_translation': true,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Өнөөдрийн үг'), findsOneWidget);
    expect(find.text('Keep learning.'), findsOneWidget);
    expect(find.text('Үргэлж суралцаарай.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Keep learning.')).dy,
      lessThan(tester.getTopLeft(find.text('Үргэлж суралцаарай.')).dy),
    );
    expect(find.text('Advice Slip'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
