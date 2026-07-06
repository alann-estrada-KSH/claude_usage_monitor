import 'dart:io';

class CreateConfiguration {
  final int windowWidth;
  final int windowHeight;

  /// Position of the top left point of the webview window
  final int windowPosX;
  final int windowPosY;

  /// the title of window
  final String title;

  final int titleBarHeight;

  final int titleBarTopPadding;

  final String userDataFolderWindows;

  final bool useWindowPositionAndSize;
  final bool openMaximized;

  /// Linux only (so far): an opaque identifier that partitions cookies/
  /// storage into their own on-disk WebKitWebContext instead of sharing the
  /// process-wide default one. `null`/empty keeps the old shared-context
  /// behavior. Lets this app give each account its own login session
  /// instead of every account overwriting the same cookie jar.
  final String? profile;

  const CreateConfiguration({
    this.windowWidth = 1280,
    this.windowHeight = 720,
    this.windowPosX = 0,
    this.windowPosY = 0,
    this.title = "",
    this.titleBarHeight = 40,
    this.titleBarTopPadding = 0,
    this.userDataFolderWindows = 'webview_window_WebView2',
    this.useWindowPositionAndSize = false,
    this.openMaximized = false,
    this.profile,
  });

  factory CreateConfiguration.platform() {
    return CreateConfiguration(
      titleBarTopPadding: Platform.isMacOS ? 24 : 0,
    );
  }

  Map toMap() => {
        "windowWidth": windowWidth,
        "windowHeight": windowHeight,
        "windowPosX": windowPosX,
        "windowPosY": windowPosY,
        "title": title,
        "titleBarHeight": titleBarHeight,
        "titleBarTopPadding": titleBarTopPadding,
        "userDataFolderWindows": userDataFolderWindows,
        "useWindowPositionAndSize": useWindowPositionAndSize,
        "openMaximized": openMaximized,
        "profile": profile ?? "",
      };
}
