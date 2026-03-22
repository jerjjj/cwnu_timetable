import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/main.dart';

void main() {
  testWidgets('Bootstrap page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CwnuTimetableApp()));

    // 等待初始化完成
    await tester.pump();

    // 验证应用启动页面渲染成功
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
