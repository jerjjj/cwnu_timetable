import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/main.dart';

void main() {
  testWidgets('Bootstrap page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CwnuTimetableApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
