import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the OpenCode Go workspace id captured from the login webview's
/// navigation (`/workspace/{id}/...` shows up right after the OAuth
/// callback). There's no API to look this up after the fact, and the
/// dashboard's usage page requires it in the URL -- scraping the root page
/// for it post-login isn't reliable since routing there is client-side
/// (SolidJS), invisible to a plain authenticated HTTP GET.
class OpenCodeWorkspaceStore {
  const OpenCodeWorkspaceStore();

  static const _storage = FlutterSecureStorage();

  String _keyFor(String accountId) => 'opencode_workspace_id_$accountId';

  Future<String?> read(String accountId) =>
      _storage.read(key: _keyFor(accountId));

  Future<void> save(String accountId, String workspaceId) =>
      _storage.write(key: _keyFor(accountId), value: workspaceId);
}
