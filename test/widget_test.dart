// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wordflow/main.dart';
import 'package:wordflow/utils/auto_update_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': false,
      'last_update_check_time': DateTime.now().millisecondsSinceEpoch,
    });
    await AutoUpdateService.instance.initialize();
  });

  testWidgets('WordFlow app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WordFlowApp());

    // Verify that our app starts (it might show onboarding or home page)
    // Since we have dynamic routing, we'll just check if the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Let the initial routing FutureBuilder resolve without waiting on a
    // network update check.
    await tester.pump();
    await tester.pump();
    
    // The app should show either onboarding or home page
    // We can check if there's at least a Scaffold present
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
