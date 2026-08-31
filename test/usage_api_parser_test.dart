import 'dart:convert';
import 'dart:io';

import 'package:claude_usage_monitor/core/models/provider_type.dart';
import 'package:claude_usage_monitor/core/scraping/usage_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const client = UsageApiClient();

  test('parses Claude fixture', () {
    final fixture = jsonDecode(
      File('test/fixtures/claude_usage.json').readAsStringSync(),
    );
    final result = client.parseFixture(AccountProviderType.claude, fixture);
    expect(result.fiveHourPercent, 23);
    expect(result.weeklyPercent, 47);
  });

  test('parses Codex fixture', () {
    final fixture = jsonDecode(
      File('test/fixtures/codex_usage.json').readAsStringSync(),
    );
    final result = client.parseFixture(AccountProviderType.codex, fixture);
    expect(result.fiveHourPercent, 31);
    expect(result.weeklyPercent, 62);
  });

  test('parses Antigravity fixture', () {
    final fixture = jsonDecode(
      File('test/fixtures/antigravity_usage.json').readAsStringSync(),
    );
    final result = client.parseFixture(
      AccountProviderType.antigravity,
      fixture,
    );
    expect(result.fiveHourPercent, closeTo(20, 0.001));
    expect(result.claudeGptWeeklyPercent, closeTo(75, 0.001));
  });

  test('parses Copilot fixture', () {
    final fixture = jsonDecode(
      File('test/fixtures/copilot_usage.json').readAsStringSync(),
    );
    final result = client.parseFixture(AccountProviderType.copilot, fixture);
    expect(result.fiveHourPercent, 40);
    expect(result.weeklyPercent, 25);
  });

  test('parses OpenCode Go fixture', () {
    final fixture = File(
      'test/fixtures/opencode_usage.html',
    ).readAsStringSync();
    final result = client.parseFixture(AccountProviderType.openCodeGo, fixture);
    expect(result.fiveHourPercent, 18);
    expect(result.weeklyPercent, 44);
    expect(result.monthlyPercent, 67);
  });

  test('retry delay uses bounded exponential backoff', () {
    expect(UsageApiClient.retryDelay(0), const Duration(milliseconds: 300));
    expect(UsageApiClient.retryDelay(1), const Duration(milliseconds: 600));
    expect(UsageApiClient.retryDelay(8), const Duration(seconds: 5));
  });
}
