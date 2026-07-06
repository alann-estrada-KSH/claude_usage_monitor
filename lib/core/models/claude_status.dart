/// Claude's own status page rollup (status.claude.com), plus any incidents
/// currently listed as unresolved. `indicator` is one of "none", "minor",
/// "major", "critical" per statuspage.io's API.
class ClaudeStatus {
  const ClaudeStatus({
    required this.indicator,
    required this.description,
    required this.fetchedAt,
    this.incidentNames = const [],
    this.error,
  });

  final String indicator;
  final String description;
  final DateTime fetchedAt;
  final List<String> incidentNames;
  final String? error;

  bool get isOperational => indicator == 'none';

  factory ClaudeStatus.unavailable(String error, {DateTime? fetchedAt}) => ClaudeStatus(
        indicator: 'unknown',
        description: 'Unknown',
        fetchedAt: fetchedAt ?? DateTime.now(),
        error: error,
      );

  factory ClaudeStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>? ?? const {};
    final incidents = (json['incidents'] as List?) ?? const [];
    return ClaudeStatus(
      indicator: status['indicator'] as String? ?? 'unknown',
      description: status['description'] as String? ?? 'Unknown',
      fetchedAt: DateTime.now(),
      incidentNames: incidents
          .whereType<Map>()
          .map((i) => i['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList(),
    );
  }
}
