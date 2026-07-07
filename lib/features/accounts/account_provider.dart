import 'package:flutter/foundation.dart';

import '../../core/models/claude_account.dart';
import '../../core/models/usage_history_point.dart';
import '../../core/notifications/usage_alert_service.dart';
import '../../core/scraping/android_account_cookie_store.dart';
import '../../core/scraping/usage_scraper.dart';
import '../../core/storage/account_store.dart';
import '../../core/storage/usage_history_store.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider({
    AccountStore? store,
    UsageScraper? scraper,
    UsageAlertService? alerts,
    UsageHistoryStore? history,
    AndroidAccountCookieStore? androidCookies,
  })  : _store = store ?? AccountStore(),
        _scraper = scraper ?? UsageScraper(),
        _alerts = alerts ?? UsageAlertService(),
        _history = history ?? UsageHistoryStore(),
        _androidCookies = androidCookies ?? const AndroidAccountCookieStore();

  final AccountStore _store;
  final UsageScraper _scraper;
  final UsageAlertService _alerts;
  final UsageHistoryStore _history;
  final AndroidAccountCookieStore _androidCookies;

  List<ClaudeAccount> _accounts = [];
  List<ClaudeAccount> get accounts => List.unmodifiable(_accounts);

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  Future<void> init() async {
    await _store.init();
    await _alerts.init();
    await _history.init();
    _accounts = _store.getAll()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  List<UsageHistoryPoint> historyFor(String accountId) => _history.forAccount(accountId);

  /// [id], when passed, must match whatever profile the login webview used
  /// (see AccountLoginPage) -- the id has to exist *before* login so both
  /// share the same isolated cookie context. Generates one if omitted.
  Future<ClaudeAccount> addAccount(String label, {String? id}) async {
    final account = ClaudeAccount(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
      isLoggedIn: true,
      // Appended at the end of the user's current order rather than 0 --
      // new accounts otherwise jump to the front of the list/focus view on
      // every reorder-sensitive screen, ahead of ones the user deliberately
      // placed first.
      sortOrder: _accounts.isEmpty ? 0 : _accounts.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
    );
    _accounts = [..._accounts, account];
    await _store.save(account);
    notifyListeners();
    return account;
  }

  /// Drag-to-reorder in Settings (see _FocusModeAccountsControl) -- persists
  /// the new order so it survives restarts and is reflected everywhere
  /// accounts are listed (dashboard, focus mode), not just in Settings.
  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    final reordered = [..._accounts];
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    _accounts = [
      for (var i = 0; i < reordered.length; i++) reordered[i].copyWith(sortOrder: i),
    ];
    notifyListeners();
    for (final account in _accounts) {
      await _store.save(account);
    }
  }

  Future<void> removeAccount(String accountId) async {
    _accounts = _accounts.where((a) => a.id != accountId).toList();
    await _store.delete(accountId);
    await _androidCookies.delete(accountId); // no-op if nothing was ever stored (desktop, or Android fallback path)
    await _ensureSomeAccountVisibleInFocusMode();
    notifyListeners();
  }

  Future<void> renameAccount(String accountId, String newLabel) async {
    _updateAccount(accountId, (a) => a.copyWith(label: newLabel));
    await _persist(accountId);
    notifyListeners();
  }

  /// Refuses to turn off the last remaining focus-mode account -- focus
  /// mode with zero accounts selected is an empty screen with no way back
  /// to settings without knowing the app has hidden nav elsewhere, so at
  /// least one must always stay on.
  Future<void> setShowInFocusMode(String accountId, bool value) async {
    if (!value) {
      final matches = _accounts.where((a) => a.id == accountId);
      final target = matches.isEmpty ? null : matches.first;
      final visibleCount = _accounts.where((a) => a.showInFocusMode).length;
      if (target != null && target.showInFocusMode && visibleCount <= 1) return;
    }
    _updateAccount(accountId, (a) => a.copyWith(showInFocusMode: value));
    await _persist(accountId);
    notifyListeners();
  }

  /// Called after removing an account -- if that left every remaining
  /// account hidden from focus mode (the removed one was the only visible
  /// one), fall back to showing the first remaining account rather than
  /// leaving focus mode with nothing to show.
  Future<void> _ensureSomeAccountVisibleInFocusMode() async {
    if (_accounts.isEmpty) return;
    if (_accounts.any((a) => a.showInFocusMode)) return;
    final first = _accounts.first;
    _updateAccount(first.id, (a) => a.copyWith(showInFocusMode: true));
    await _persist(first.id);
  }

  Future<void> refreshAll() async {
    if (_isRefreshing || _accounts.isEmpty) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      for (final account in _accounts) {
        await refreshUsage(account.id);
      }
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshUsage(String accountId) async {
    final previous = _accounts.firstWhere((a) => a.id == accountId).lastKnownUsage;
    final snapshot = await _scraper.fetchUsage(profile: accountId);
    _updateAccount(
      accountId,
      (a) => a.copyWith(lastKnownUsage: snapshot, lastFetchedAt: DateTime.now()),
    );
    await _persist(accountId);
    final account = _accounts.firstWhere((a) => a.id == accountId);
    await _alerts.check(account: account, previous: previous, next: snapshot);
    if (snapshot.isAvailable) {
      await _history.append(
        accountId,
        UsageHistoryPoint(
          timestamp: DateTime.now(),
          fiveHourPercent: snapshot.fiveHourPercent,
          weeklyPercent: snapshot.weeklyPercent,
        ),
      );
    }
    notifyListeners();
  }

  void _updateAccount(String accountId, ClaudeAccount Function(ClaudeAccount) update) {
    _accounts = _accounts
        .map((a) => a.id == accountId ? update(a) : a)
        .toList();
  }

  Future<void> _persist(String accountId) async {
    for (final account in _accounts) {
      if (account.id == accountId) {
        await _store.save(account);
        return;
      }
    }
  }
}
