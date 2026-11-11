import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_tank_monitor/screens/splash/splash_screen.dart';

void main() {
  group('SplashScreen Mobile Screen Fit & Responsiveness Tests', () {
    testWidgets('Renders properly on standard mobile phone (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Verify widget rendered with logo, tagline, and progress indicator
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('SMART WATER MONITORING'), findsOneWidget);
      expect(find.text('MIT ADT UNIVERSITY'), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('Renders without overflow on compact screen (320x568)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow on tall modern phone (412x915)', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
    });
  });
}
