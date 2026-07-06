import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'core/background/session_keepalive.dart';
import 'core/connectivity/connectivity_provider.dart';
import 'core/notifications/notification_service.dart';
import 'core/status/claude_status_provider.dart';
import 'features/accounts/account_provider.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/settings/settings_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  // Note: desktop_webview_window normally relaunches this app in a second
  // Flutter engine/view to render each native window's title bar, passing
  // ["web_view_title_bar", "<id>"] as args -- our vendored patch
  // (third_party/desktop_webview_window) removes that secondary view
  // entirely (it crashed on close inside Flutter's own precompiled engine),
  // so that entrypoint path no longer exists and main() takes no arguments.
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // flutter_inappwebview only has a platform implementation on Android here
  // (Linux/Windows use desktop_webview_window instead -- see README).
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(false);
  }
  await NotificationService.instance.init();
  await SessionKeepAlive.initialize();
  runApp(const ClaudeUsageMonitorApp());
}

class ClaudeUsageMonitorApp extends StatelessWidget {
  const ClaudeUsageMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => ClaudeStatusProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Claude Usage Monitor',
            theme: AppTheme.light(accentColor: settings.accentColor, fontChoice: settings.fontChoice),
            darkTheme: AppTheme.dark(accentColor: settings.accentColor, fontChoice: settings.fontChoice),
            themeMode: settings.themeMode,
            locale: settings.languageCode != null ? Locale(settings.languageCode!) : null,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DashboardPage(),
          );
        },
      ),
    );
  }
}
