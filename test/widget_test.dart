import 'package:flutter_test/flutter_test.dart';
import 'package:zenvora/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZenvoraApp());
    await tester.pumpAndSettle();

    // Verify app widget mounts cleanly
    expect(find.byType(ZenvoraApp), findsOneWidget);
  });
}
