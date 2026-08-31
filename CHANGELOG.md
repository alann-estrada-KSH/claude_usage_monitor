# Changelog

All notable changes to this project are documented here, one entry per
tagged release. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

No changes yet.

## [1.4.2] - 2026-08-31

- ci: fix `releaseFiles` in the Play Store upload step -- it's a
  comma-separated list (`fast-glob` under the hood), not one path per line;
  the multi-line YAML block from v1.4.1 concatenated both paths into a
  single literal pattern (embedded `\n` and all), so the action could not
  find even the `.aab` that had just built successfully
- chore: version bump to re-run the release workflow end-to-end

## [1.4.1] - 2026-08-31

- ci: fix `build-android` running `./gradlew :wear:assembleRelease` from the
  repo root instead of `android/` -- the wrapper lives there, so the step
  failed immediately (`exit code 127`) and the v1.4.0 tag published the
  Linux and Windows assets but never reached the Play Store upload
- chore: version bump to re-run the release workflow end-to-end

## [1.4.0] - 2026-08-31

- feat: Wear OS companion module -- syncs sanitized usage JSON (no cookies,
  OAuth tokens, or provider sessions) from the phone over the Wear Data
  Layer to a watch app and a configurable usage complication
- feat: Tasker integration -- broadcasting
  `com.claudeusagemonitor.claude_usage_monitor.TASKER_REFRESH` opens the app
  and triggers its normal refresh path, rate-limited to once per 30 seconds
- ci: release workflow now also builds `:wear:assembleRelease` and uploads
  the resulting APK to the Play Store internal track alongside the phone AAB
- fix: Windows auto-update now checks the downloaded installer's Authenticode
  signature before running it, and refuses to launch unsigned installers
  (current unsigned builds require manual install until signing is set up)
- fix: restrict Windows update downloads to `github.com`/`githubusercontent.com`
  hosts

## [1.3.2] - 2026-08-28

- fix: retry Linux startup with software rendering after a native GPU
  `SIGSEGV`, preserving hardware rendering for healthy launches

## [1.3.1] - 2026-08-28

- fix: restore the individual Android widget to a compact 2×1 layout while
  keeping session and weekly usage visible side by side

## [1.3.0] - 2026-08-28

- feat: local read-only API for Linux and Windows with generated account IDs,
  random secret keys, configurable ports, and rate limiting
- feat: Android home-screen widgets with account selection, all-account
  overview, provider labels, and horizontal/vertical resizing
- feat: Android pinned usage notification with selectable accounts
- feat: desktop floating usage monitor with always-on-top behavior, opacity,
  account selection, reset timers, and provider labels
- fix: Android release builds retain network access and existing WebView
  sessions while publishing normalized usage to widgets and notifications
- docs: document local API setup, authentication, endpoints, and security

## [1.2.1] - 2026-08-04

- ci: automated Play Store publishing -- tagging a release now builds a
  signed AAB and uploads it straight to the internal testing track via a
  dedicated service account, no manual Play Console upload needed
- chore: version bump to validate the new CI path end-to-end

## [1.2.0] - 2026-08-04

- feat: OpenCode Go provider support -- scrapes the authenticated dashboard
  (no public usage API exists upstream) for rolling/weekly/monthly quota;
  the workspace id needed for that is captured from the login webview's own
  navigation and stored per account
- fix: Android login WebView User-Agent regression that made Google reject
  any provider's "Sign in with Google" flow with `disallowed_useragent`
- fix: OAuth `code=` interception in the login webview was matching any
  provider's callback URL instead of only Antigravity's, breaking Codex's
  "Sign in with Google" token exchange
- feat: `UsageSnapshot` gained a third generic monthly usage window,
  surfaced in the dashboard for providers that report it

## [1.1.9] - 2026-07-17

- feat: Antigravity local probe support (reads usage from the
  Antigravity/Gemini CLI's local session instead of a login flow)
- feat: multi-group model usage bars
- feat: mobile-specific account list filtering

## [1.1.8] - 2026-07-13

- fix: generate the apt Release file with `apt-ftparchive` instead of a
  hand-written heredoc, so `apt update` stops warning about missing
  Date/SHA256 index hashes

## [1.1.7] - 2026-07-13

- feat: Android home screen widget + Quick Settings tile
- feat: broader error handling and localization coverage
- fix: missing `cachedDataWarning` l10n key

## [1.1.6] - 2026-07-06

- chore: version bump only

## [1.1.5] - 2026-07-06

- feat: multi-provider support for Codex and GitHub Copilot, with
  provider-specific quota bars and localization
- fix: Android multi-org usage picking the wrong org's (0%) usage instead
  of whichever org actually has data
- fix: a race where the Android login WebView started loading before the
  previous account's cookie/storage clear had finished, letting sessions
  bleed between accounts
- fix: Google sign-in on Android needed a real popup WebView bound to its
  own window id instead of loading the OAuth placeholder URL in the main view
- fix: real per-account cookie isolation on Android via captured cookies in
  Keystore-backed secure storage, working around `android.webkit.CookieManager`
  being a single global jar with no per-WebView isolation
- fix: the Android login page's "Done" button was a silent no-op
  (`_desktopWebview` is always null on Android)
- fix: missing `INTERNET` permission in the release manifest
- docs: privacy policy covering the Android cookie-capture behavior

## [1.1.0] - 2026-07-06

- ci: initial release pipeline -- Linux `.deb` + apt repo and Windows
  installer, built and published on every `vX.Y.Z` tag push
- ci: pin `build-windows` to `windows-2022` (a Windows webview plugin
  dependency doesn't compile on newer MSVC)

## [Initial commit] - 2026-07-06

- Claude Usage Monitor: cross-platform (Linux/Windows/Android) usage
  dashboard for Claude, scraping session/weekly limits from an
  authenticated login session
