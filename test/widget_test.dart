import 'package:flutter_test/flutter_test.dart';
import 'package:unicore_mobile_app/main.dart';

void main() {
  testWidgets('renders Unicore login screen', (tester) async {
    await tester.pumpWidget(const UnicoreApp());

    expect(find.text('UNiCORE'), findsWidgets);
    expect(find.text('Нэвтрэх'), findsOneWidget);
    expect(find.text('Unicore 3.0-д тавтай морил'), findsOneWidget);
  });
}
