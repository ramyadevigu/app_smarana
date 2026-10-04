import 'package:app_smarana/app/app_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup splash shows the supplied background and compact logo', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StartupSplashScreen()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final logo = tester.widget<Image>(
      find.byKey(const ValueKey('startup-logo')),
    );
    expect(logo.width, 128);
    expect(logo.height, 160);

    expect(find.byKey(const ValueKey('startup-background')), findsOneWidget);
  });
}
