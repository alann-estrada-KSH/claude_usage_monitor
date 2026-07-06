import 'dart:convert';
import 'dart:io';

import '../models/claude_status.dart';

/// Reads Claude's public status page API (status.claude.com) -- no auth,
/// no cookies, not tied to any account. https://status.claude.com/api
class ClaudeStatusService {
  const ClaudeStatusService();

  static const _summaryUrl = 'https://status.claude.com/api/v2/summary.json';

  Future<ClaudeStatus> fetchStatus() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_summaryUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return ClaudeStatus.unavailable('${response.statusCode}: $body');
      }
      return ClaudeStatus.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (e) {
      return ClaudeStatus.unavailable('$e');
    } finally {
      client.close(force: true);
    }
  }
}
