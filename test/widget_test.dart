import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unicore_mobile_app/screens/login_screen.dart';
import 'package:unicore_mobile_app/services/unicore_api.dart';
import 'package:unicore_mobile_app/services/device_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unicore_mobile_app/main.dart';

class PendingApi extends UnicoreApi {
  final pending = Completer<String>();
  @override
  Future<String> login(
    String login,
    String password, {
    void Function(String)? onProgress,
  }) {
    onProgress?.call('Серверээс ID хайж байна…');
    return pending.future;
  }
}

void main() {
  testWidgets('renders Unicore login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const UnicoreApp());
    await tester.pumpAndSettle();

    expect(find.text('UNiCORE 4.0'), findsWidgets);
    expect(find.text('Нэвтрэх'), findsWidgets);
    expect(find.text('Unicore 4.0-д тавтай морил'), findsOneWidget);
  });
  testWidgets('login shows slow progress and keeps failed stage visible', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = PendingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(api: api, onLoggedIn: (_, _, _) async {}),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user@example.test');
    await tester.enterText(fields.at(1), 'secret');
    await tester.ensureVisible(find.text('Нэвтрэх'));
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.textContaining('Хүсэлт үргэлжилж байна'), findsOneWidget);
    api.pending.completeError(
      const DeviceLookupException(
        'Серверээс ID хайж байна…',
        'Холболт тасарлаа',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Холболт тасарлаа'), findsOneWidget);
    expect(find.text('Нэвтрэлт амжилтгүй'), findsOneWidget);
  });
}
