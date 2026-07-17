import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/claude_account.dart';
import '../../core/models/provider_type.dart';
import '../../core/models/usage_history_point.dart';
import '../../core/notifications/usage_alert_service.dart';
import '../../core/scraping/android_account_cookie_store.dart';
import '../../core/scraping/usage_scraper.dart';
import '../../core/storage/account_store.dart';
import '../../core/storage/app_settings_store.dart';
import '../../core/storage/usage_history_store.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider({
    AccountStore? store,
    UsageScraper? scraper,
    UsageAlertService? alerts,
    UsageHistoryStore? history,
    AndroidAccountCookieStore? androidCookies,
    AppSettingsStore? settingsStore,
  })  : _store = store ?? AccountStore(),
        _scraper = scraper ?? UsageScraper(),
        _alerts = alerts ?? UsageAlertService(),
        _history = history ?? UsageHistoryStore(),
        _androidCookies = androidCookies ?? const AndroidAccountCookieStore(),
        _settingsStore = settingsStore ?? AppSettingsStore();

  final AccountStore _store;
  final UsageScraper _scraper;
  final UsageAlertService _alerts;
  final UsageHistoryStore _history;
  final AndroidAccountCookieStore _androidCookies;
  final AppSettingsStore _settingsStore;

  List<ClaudeAccount> _accounts = [];
  List<ClaudeAccount> get accounts => List.unmodifiable(_accounts);

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  Future<void> init() async {
    await _store.init();
    await _alerts.init();
    await _history.init();
    await _settingsStore.init();
    _accounts = _store.getAll()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  AppSettings _loadSettings() => _settingsStore.load();

  List<UsageHistoryPoint> historyFor(String accountId) => _history.forAccount(accountId);

  /// [id], when passed, must match whatever profile the login webview used
  /// (see AccountLoginPage) -- the id has to exist *before* login so both
  /// share the same isolated cookie context. Generates one if omitted.
  Future<ClaudeAccount> addAccount(
    String label, {
    String? id,
    AccountProviderType providerType = AccountProviderType.claude,
  }) async {
    final account = ClaudeAccount(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
      providerType: providerType,
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

  static const _widgetChannel = MethodChannel('claude_usage_monitor/widget');

  Future<void> refreshAll() async {
    if (_isRefreshing || _accounts.isEmpty) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      for (final account in _accounts) {
        await refreshUsage(account.id);
      }
      if (Platform.isAndroid) await _updateAndroidWidgets();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Writes account data to SharedPreferences so the Android home-screen
  /// widget and Quick Tile can read it without an active Flutter isolate, then
  /// sends a MethodChannel ping so MainActivity can push an immediate widget
  /// update while the app is in the foreground.
  Future<void> _updateAndroidWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usage_widget_count', _accounts.length);
      for (var i = 0; i < _accounts.length; i++) {
        final a = _accounts[i];
        final u = a.lastKnownUsage;
        await prefs.setString('usage_widget_${i}_label', a.label);
        await prefs.setDouble('usage_widget_${i}_five_hour', u?.fiveHourPercent ?? -1.0);
        await prefs.setDouble('usage_widget_${i}_weekly', u?.weeklyPercent ?? -1.0);
        await prefs.setBool('usage_widget_${i}_has_error',
            a.lastFetchError != null && u == null);
        await prefs.setBool('usage_widget_${i}_session_expired', a.lastFetchSessionExpired);
      }
      await prefs.setString('usage_widget_updated_at', DateTime.now().toIso8601String());
      await _widgetChannel.invokeMethod('updateWidgets');
    } catch (_) {
      // Widget update failure must never surface to the user.
    }
  }

  Future<void> refreshUsage(String accountId) async {
    final account = _accounts.firstWhere((a) => a.id == accountId);
    final previous = account.lastKnownUsage;
    final snapshot = await _scraper.fetchUsage(
      profile: accountId,
      providerType: account.providerType,
    );
    if (snapshot.isAvailable) {
      _updateAccount(
        accountId,
        (a) => a.copyWith(
          lastKnownUsage: snapshot,
          lastFetchedAt: DateTime.now(),
          clearLastFetchError: true,
          lastFetchSessionExpired: false,
        ),
      );
      await _persist(accountId);
      final account = _accounts.firstWhere((a) => a.id == accountId);
      final settings = _loadSettings();
      await _alerts.check(
        account: account,
        previous: previous,
        next: snapshot,
        warningThreshold: settings.warningThresholdPercent,
        criticalThreshold: settings.criticalThresholdPercent,
      );
      await _history.append(
        accountId,
        UsageHistoryPoint(
          timestamp: DateTime.now(),
          fiveHourPercent: snapshot.fiveHourPercent,
          weeklyPercent: snapshot.weeklyPercent,
        ),
      );
    } else if (snapshot.sessionExpired) {
      _updateAccount(
        accountId,
        (a) => a.copyWith(
          lastKnownUsage: snapshot,
          lastFetchedAt: DateTime.now(),
          clearLastFetchError: true,
          lastFetchSessionExpired: true,
        ),
      );
      await _persist(accountId);
    } else {
      _updateAccount(
        accountId,
        (a) => a.copyWith(
          lastFetchedAt: DateTime.now(),
          lastFetchError: snapshot.parseError ?? 'Unknown error',
          lastFetchSessionExpired: false,
        ),
      );
      await _persist(accountId);
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
