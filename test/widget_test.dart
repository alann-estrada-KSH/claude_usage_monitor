import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:claude_usage_monitor/main.dart';

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_test').path);
  });

  testWidgets('renders app title and empty account state', (tester) async {
    await tester.pumpWidget(const ClaudeUsageMonitorApp());
    await tester.pump();

    expect(find.text('Usage Monitor'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
