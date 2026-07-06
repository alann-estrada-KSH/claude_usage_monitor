import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// System tray + close-to-tray behavior (Linux/Windows/macOS desktop only --
/// no-op on Android, which has no equivalent concept). This app's whole job
/// is periodic background refreshes, so quitting on window close would
/// defeat the "leave it running, glance at it occasionally" use case --
/// closing the window hides it to the tray instead; the tray menu is the
/// only way to actually quit.
class AppTrayController with TrayListener, WindowListener {
  AppTrayController({required this.onRefreshNow});

  final Future<void> Function() onRefreshNow;
  bool _initialized = false;

  List<String> _usageLines = const [];
  List<String>? _lastRebuiltLines;

  // tray_manager's MenuItem mints a brand-new id in its constructor every
  // time one is created -- rebuilding the whole menu on every usage refresh
  // (even when nothing changed) silently orphans whatever id the tray host
  // already has cached for an open/displayed menu. Click it after that and
  // the click is a no-op (confirmed via dbusmenu: "the ID supplied does not
  // refer to a menu item we have"). Building the static items exactly once
  // and reusing the same instances keeps their ids stable for the whole
  // process lifetime; only the disabled usage-line items (never clickable,
  // so a stale id there is harmless) get recreated.
  MenuItem? _showHideItem;
  MenuItem? _refreshItem;
  MenuItem? _quitItem;

  static const _showHideKey = 'show_hide';
  static const _refreshKey = 'refresh_now';
  static const _quitKey = 'quit';

  bool get isSupported => !Platform.isAndroid;

  Future<void> init({
    required String showHideLabel,
    required String refreshLabel,
    required String quitLabel,
    required String tooltip,
  }) async {
    if (!isSupported || _initialized) return;
    _showHideItem = MenuItem(key: _showHideKey, label: showHideLabel);
    _refreshItem = MenuItem(key: _refreshKey, label: refreshLabel);
    _quitItem = MenuItem(key: _quitKey, label: quitLabel);
    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);
      trayManager.addListener(this);

      await trayManager.setIcon('assets/icon/app_icon_512.png');
      await trayManager.setToolTip(tooltip);
      _initialized = true;
      await _rebuildMenu();
    } catch (e) {
      // Missing system tray library, no tray host running (some minimal
      // WMs), or similar -- degrade to "just a normal window, no tray"
      // rather than taking the app down.
      print('[AppTrayController] init failed, tray disabled: $e');
    }
  }

  /// Updates the hover tooltip. Works reliably on Windows (real
  /// Shell_NotifyIcon tooltip). On Linux this is best-effort only: the
  /// AppIndicator library this app links against (libayatana-appindicator)
  /// has no API for the DBus "ToolTip" property at all -- only a "Title"
  /// property, which most tray hosts (including Plasma) don't surface as a
  /// hover tooltip. [updateUsageSummary] is the reliable path on Linux.
  Future<void> updateTooltip(String tooltip) async {
    if (!_initialized) return;
    try {
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      print('[AppTrayController] updateTooltip failed: $e');
    }
  }

  /// Shows current usage as disabled (non-clickable) lines at the top of
  /// the tray's context menu -- one per account. Menus work identically
  /// across every Linux tray host regardless of hover-tooltip support, so
  /// this is what actually answers "let me see the limits from the tray"
  /// on Linux; on Windows it's a bonus next to the real tooltip.
  Future<void> updateUsageSummary(List<String> lines) async {
    _usageLines = lines;
    if (!_initialized) return;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    if (listEquals(_usageLines, _lastRebuiltLines)) return;
    _lastRebuiltLines = _usageLines;
    try {
      await trayManager.setContextMenu(
        Menu(items: [
          for (final line in _usageLines) MenuItem(label: line, disabled: true),
          if (_usageLines.isNotEmpty) MenuItem.separator(),
          _showHideItem!,
          MenuItem.separator(),
          _refreshItem!,
          MenuItem.separator(),
          _quitItem!,
        ]),
      );
    } catch (e) {
      print('[AppTrayController] menu rebuild failed: $e');
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconMouseDown() => _toggleWindow();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _showHideKey:
        _toggleWindow();
      case _refreshKey:
        onRefreshNow();
      case _quitKey:
        _quit();
    }
  }

  Future<void> _quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    // setPreventClose(true) stops the OS from actually closing the window
    // when the user clicks its own "x" -- this is what fires instead. Hide
    // to the tray rather than exit.
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
