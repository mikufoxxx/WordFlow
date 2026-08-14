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

  testWidgets('WordFlow app creates a MaterialApp shell', (
    WidgetTester tester,
  ) async {
    // Build only the first frame. Once its initialization Future resolves,
    // onboarding starts character animations that are covered by focused widget
    // tests rather than this app-shell smoke test.
    await tester.pumpWidget(const WordFlowApp());

    // The root application shell should be created before routing completes.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Dispose the root deterministically so no async work survives the test.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
