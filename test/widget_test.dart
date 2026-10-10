import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unicore_mobile_app/main.dart';

void main() {
  testWidgets('renders Unicore login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UnicoreApp());

    expect(find.text('UNiCORE'), findsWidgets);
    expect(find.text('Нэвтрэх'), findsWidgets);
    expect(find.text('Unicore 3.0-д тавтай морил'), findsOneWidget);
  });
}
