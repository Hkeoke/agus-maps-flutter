// Basic widget test for the Rikera app

import 'package:flutter_test/flutter_test.dart';

import 'package:rikera_app/app/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RikeraApp());

    // Verify that the app loads with the setup complete message
    expect(find.text('Rikera App - Setup Complete'), findsOneWidget);
  });
}
