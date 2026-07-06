# Claude Usage Monitor

Unofficial, community tool. **Not affiliated with, endorsed by, or built by Anthropic.**

It reads the usage percentages shown on your own `claude.ai/settings/usage`
page and displays them in a small tray/dashboard app. It does not automate
Claude, does not send messages, and does not consume any of your message
quota. It never calls `/v1/messages` or any other inference endpoint.

## How it works

There is no public API for Claude Pro/Team usage data. This app:

1. Opens a real WebView pointed at `claude.ai/login` so you log in exactly as
   you would in a browser. The session cookie that results is stored by the
   OS-level WebView engine itself (Android WebView / WebView2 / WPE WebKit) —
   this app never reads, copies, or transmits that cookie.
2. On a timer (default 90s, floor of 30s, configurable), loads
   `claude.ai/settings/usage` in a hidden WebView reusing that same session,
   reads the rendered page text, and regex-parses out the 5-hour and weekly
   usage percentages and reset times.
3. If Anthropic changes the page and parsing fails, the UI shows "usage data
   not available" instead of crashing or showing stale/wrong numbers.

## Privacy

- 100% local. No telemetry, no analytics, no ads, no home-phoning server.
- Cookies/session data never leave the device and are never logged.
- Account labels and last-seen usage percentages are cached locally (Hive)
  purely so the dashboard has something to show before the first refresh.

## Platform status

| Platform | WebView backend | Status |
|----------|-----------------|--------|
| Android  | `flutter_inappwebview` (embedded WebView) | Supported |
| Windows  | `desktop_webview_window` (WebView2, native window) | Supported |
| Linux    | `desktop_webview_window` (webkit2gtk-4.1, native window) | Supported. `flutter_inappwebview`'s own Linux plugin requires WPE WebKit, which Ubuntu doesn't package — see below. |

Login on Linux/Windows opens a separate native window rather than an embedded
WebView (the OS-native webview on those platforms isn't embeddable the way
Android's is); a "Done" button in the app closes it once you've logged in.

## Installing / updating

Releases are built by `.github/workflows/release.yml` on every `vX.Y.Z` tag
push and published to a [GitHub Release](https://github.com/alann-estrada-KSH/claude_usage_monitor/releases)
with a Linux `.deb` and a Windows installer.

**Linux (apt):**

```bash
echo "deb [trusted=yes] https://alann-estrada-ksh.github.io/claude_usage_monitor/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-usage-monitor.list
sudo apt update
sudo apt install claude-usage-monitor
```

Future `apt upgrade` picks up new releases automatically -- the repo is
unsigned (`[trusted=yes]`), matching a small unofficial personal tool with no
signing infrastructure; don't add this line if that tradeoff bothers you and
just grab the `.deb` from Releases instead.

**Windows:** download `ClaudeUsageMonitorSetup.exe` from the latest release
and run it, or use Settings > Updates inside the app once installed --
it checks GitHub Releases, downloads, and runs the installer for you.

**Android:** not distributed anywhere (no Play Store listing) -- build and
`flutter install` it yourself, or sideload the debug/release APK.

### Vendored patches: `desktop_webview_window` on Linux

`third_party/desktop_webview_window` is a local fork of the pub.dev package
(pinned via `dependency_overrides` in `pubspec.yaml`). The stock package
crashed the whole process on essentially every window close on Linux, via
four compounding bugs found by reading its C++ source and cross-referencing
`coredumpctl`/`journalctl` crash dumps (nothing was printed to stdout for
most of these -- they were silent SIGSEGVs):

1. **Popup handling (`on_create`)** -- fired when a page opens a popup
   (`window.open()`, `target="_blank"`, Google's "Sign in with Google"
   button). Upstream returned the *same* `WebKitWebView` as if it were a new
   one, which corrupts WebKit's internal state:
   `optional<WindowFeatures>::operator*(): Assertion '_M_is_engaged()' failed`.
   Fixed by returning `nullptr` (WebKitGTK's documented way to decline
   creating a new view) and loading the popup's URL into the existing view
   instead.

2. **Window-close use-after-free** -- the `"destroy"` signal handler called
   `window->on_close_callback_()` *first*, which erases the owning
   `std::unique_ptr<WebviewWindow>` (freeing `this`), and only *then* read
   `window->window_id_` / `window->method_channel_` -- a use-after-free
   crashing on every single window close, not just popups (including our
   own invisible background-scraper windows). Fixed by reading what's
   needed before running the callback that frees the object.

3. **Missing title-bar dispatch** -- the plugin relaunches the same compiled
   app in a second Flutter engine/view to render each window's title bar
   (back/forward/reload/close), passing `["web_view_title_bar", "<id>"]` as
   `main()` arguments. Our `main()` ignored them, so that secondary view ran
   our *entire dashboard app* instead of a title bar -- this is what made
   the login window's header show the main window's own UI. Fixed by
   calling `runWebViewTitleBarWidget(args)` in `main()` before anything
   else.

4. **Engine bug in the secondary view's teardown** -- even with (3) fixed,
   removing that secondary Flutter view on window close crashed *inside
   Flutter's own precompiled `libflutter_linux_gtk.so`*
   (`FlutterEngineRemoveView` failing on "the implicit view"), not in any
   patchable source. Since we don't need navigation chrome for a login/scrape
   webview anyway, the fix removes the secondary view entirely rather than
   trying to make its content harmless -- `webview_window.cc`'s constructor
   no longer calls `fl_view_new()` at all.

See the comments at each fix site in
`third_party/desktop_webview_window/linux/webview_window.cc` for the full
detail.

### Linux build dependencies

```bash
sudo apt install -y libwebkit2gtk-4.1-dev libsoup-3.0-dev libgtk-3-dev libsecret-1-dev cmake ninja-build clang
```

**If Flutter is installed via `snap install --classic flutter`:** use `tool/flutter`
instead of the bare `flutter` command for every command that touches the Linux
build (`run -d linux`, `build linux`, `clean`). Plain `flutter` still works fine
for `pub get`, `analyze`, `test`, Android, etc.

```bash
./tool/flutter run -d linux
./tool/flutter build linux --debug
```

Why this is needed: the snap's `bin/flutter` launcher sources a `bootstrap.sh`
that the snap rewrites into the SDK checkout on every invocation. It prepends
the snap's own bundled (old) glib/cmake/ld to `PATH`/`PKG_CONFIG_PATH`, which
breaks `pkg-config` resolution for `webkit2gtk-4.1`/`libsoup-3.0` (need glib
≥2.70; the snap bundles 2.64) and breaks linking against a modern system libc
(the snap's `ld` can't read the RELR relocations current glibc uses). No env
override passed to `bin/flutter` survives that sourcing since it happens
downstream, inside the script itself. `tool/flutter` calls the compiled
`flutter_tools.snapshot` directly, skipping that launcher entirely, so it's
immune to the snap rewriting the file again.

The durable fix is to stop using the Flutter *snap* for Linux desktop builds --
install Flutter via the official git/tar.gz method instead. `tool/flutter`
is a workaround for keeping the snap install working.

## Current scope

Implemented: multi-account (isolated per account on Linux/Windows via a
WebKitWebContext per profile; on Android, via an app-captured cookie
snapshot in encrypted storage -- see the privacy policy for why Android
needs a different approach), system tray (Linux/Windows), local
notifications on threshold crossings, focus/fullscreen mode, Claude status
integration, configurable themes/thresholds, and an Android background
keep-alive ping to avoid session expiry.

Not implemented: iOS/macOS (no reason it couldn't work, just untested and
unbuilt).

## Development

```bash
flutter pub get
flutter run -d windows   # or android
./tool/flutter run -d linux   # see Linux build dependencies above for why this differs
flutter analyze
flutter test
```

## Disclaimer

This project is not built, maintained, or supported by Anthropic. It works
by reading a settings page you already have access to in your browser; it
does not defeat any authentication, does not scrape other users' data, and
does not interact with the Claude API or any inference endpoint.
