import 'package:flutter_test/flutter_test.dart';
import 'package:zenvora/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZenvoraApp());

    // Verify that Zenvora title is present
    expect(find.text('ZENVORA'), findsOneWidget);
  });
}
