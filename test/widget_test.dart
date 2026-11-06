import 'package:flutter_test/flutter_test.dart';

import 'package:my_serve/main.dart';

void main() {
  testWidgets('MyServe app loads home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyServeApp());

    expect(find.text('MyServe'), findsOneWidget);
    expect(find.text('Find the right service'), findsOneWidget);
    expect(find.text('Explore Services'), findsOneWidget);
  });
}
