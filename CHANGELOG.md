# Changelog

All notable changes to this project are documented here, one entry per
tagged release. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

- docs: note how to request Android internal tester access in the README

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
