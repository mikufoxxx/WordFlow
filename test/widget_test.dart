// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wordflow/main.dart';

void main() {
  testWidgets('WordFlow app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WordFlowApp());

    // Verify that our app starts (it might show onboarding or home page)
    // Since we have dynamic routing, we'll just check if the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Wait for any async operations to complete
    await tester.pumpAndSettle();
    
    // The app should show either onboarding or home page
    // We can check if there's at least a Scaffold present
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
