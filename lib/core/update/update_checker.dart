import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import 'app_update_info.dart';

/// Windows-only in-app updater: checks GitHub Releases for a newer version,
/// downloads the installer, and runs it. Linux updates instead through the
/// apt repo published at
/// https://alann-estrada-ksh.github.io/claude_usage_monitor/apt (see
/// .github/workflows/release.yml and README) -- apt already handles
/// download+install there, so there's nothing for the app itself to do.
class UpdateChecker {
  const UpdateChecker();

  static const _latestReleaseUrl =
      'https://api.github.com/repos/alann-estrada-KSH/claude_usage_monitor/releases/latest';

  bool get isSupported => Platform.isWindows;

  /// Returns update info if GitHub's latest release is newer than the
  /// running app, `null` if already current (or on any error -- a failed
  /// check should never be mistaken for "you're on the latest version").
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'claude_usage_monitor-update-checker');
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String? ?? '';
      final remoteVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final currentVersion = (await PackageInfo.fromPlatform()).version;
      if (!_isNewer(remoteVersion, currentVersion)) return null;

      final assets = (json['assets'] as List?) ?? const [];
      final installerAsset = assets.cast<Map<String, dynamic>>().where(
            (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.exe'),
          );
      if (installerAsset.isEmpty) return null;

      return AppUpdateInfo(
        version: remoteVersion,
        downloadUrl: installerAsset.first['browser_download_url'] as String,
        releaseUrl: json['html_url'] as String? ?? '',
      );
    } catch (e) {
      print('[UpdateChecker] check failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads [url] to a temp file, reporting 0-1 progress via [onProgress].
  Future<File> downloadInstaller(String url, {void Function(double)? onProgress}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final total = response.contentLength;
      final tempDir = await Directory.systemTemp.createTemp('claude_usage_monitor_update');
      final file = File(p.join(tempDir.path, 'ClaudeUsageMonitorSetup.exe'));
      final sink = file.openWrite();
      var received = 0;
      await response.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      });
      await sink.close();
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Launches the downloaded installer (detached, outliving this process)
  /// then exits the app so the installer can overwrite its files --
  /// `CloseApplications=yes` in installer.iss also handles this if the
  /// app is somehow still running.
  Future<void> runInstallerAndExit(File installer) async {
    await Process.start(installer.path, [], mode: ProcessStartMode.detached);
    exit(0);
  }

  bool _isNewer(String remote, String current) {
    final remoteParts = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    for (var i = 0; i < remoteParts.length || i < currentParts.length; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r != c) return r > c;
    }
    return false;
  }
}
