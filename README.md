# Gratideo

[![Android APK](https://github.com/KagChi/gratideo/actions/workflows/android.yml/badge.svg)](https://github.com/KagChi/gratideo/actions/workflows/android.yml)

The daily rhythm for leaders who put God first. Flutter, Android first, iOS from the same code.

## CI: APK from GitHub Actions

Every push to `main`, every pull request, and manual runs build a release APK on
GitHub's runners (workflow: `.github/workflows/android.yml`, Flutter 3.47.8, JDK 17).
Download it from the run's **Artifacts** section, or install it directly on a phone.

Pushing a tag like `v0.1.0` also builds the Play Store `.aab` and attaches both files
to a GitHub Release:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

The CI build signs with Flutter's debug key, which is fine for testers but not for
the Play Store. For a properly signed release, add `android/key.properties` and your
keystore as repository secrets and wire them into the workflow.

## Accounts

Sign in and register talk to a Cloudflare Worker with a D1 database, deployed from
`backend/` (see [backend/README.md](backend/README.md)). The password never leaves the
phone: the app derives a PBKDF2-SHA256 verifier and sends only that.

The app points at `https://gratideo-api.im-maxyacademy.workers.dev` by default. To use
another deployment, build with `--dart-define=API_BASE_URL=https://your-worker.workers.dev`,
or set the `API_BASE_URL` repository variable so CI picks it up.

Prayers, thanks and journal entries are stored in SQLite on the phone and synced to
D1 through `POST /v1/sync`, so the same account sees them on every device. Writes are
local first (the phone keeps working offline); each pass pushes the rows it changed and
then walks the server pages with a cursor, so nothing is pulled in one big response.
The last write wins on conflicts. List screens show a pulsing skeleton while the first
load lands.

## Build it (about 20 minutes the first time)

1. Install Flutter (stable) and Android Studio with an Android SDK. `flutter doctor` should show Android ticked.
2. In this folder: `chmod +x setup.sh && ./setup.sh`
   It generates the platform folders, lays the Android manifest and `MainActivity.kt` over them, sets `minSdk 23` and desugaring, and fetches packages.
3. Turn on USB debugging on the Fold 7, plug it in, then `flutter run --release`.
4. An installable APK for testers: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
   For the Play Store: `flutter build appbundle --release`.

If `setup.sh` could not patch the Gradle file, open `android/app/build.gradle.kts` and make sure it has:

```kotlin
android { defaultConfig { minSdk = 23 } compileOptions { isCoreLibraryDesugaringEnabled = true } }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
```

## First run checklist

- Allow notifications when asked (three daily reminders).
- Tap Selah → Focus to grant Do Not Disturb access once. After that, Selah silences everything except alarms and restores it on Amen.
- Soundscape: the pill at the top of Today. The three sounds are bundled loops in `assets/audio`.

## What is where

| Folder | What |
| --- | --- |
| `lib/theme` | Morning Gold and Night Watch tokens; day 5:00–17:59, night otherwise |
| `lib/data` | SQLite (prayers, thanks, entries), settings, bundled content and the verse-of-the-day rotation |
| `lib/services` | soundscape (just_audio), reminders, Do Not Disturb channel, in-app purchase |
| `lib/screens` | Today, Prayers, Thanks, Journal, Remember, Selah, Confessions, Settings |
| `assets/data` | `confessions.json` (59, BSB) and `verses.json` (385, BSB) |
| `android_overlay` | Manifest and `MainActivity.kt` copied in by `setup.sh` |

## Before the store

- Create the in-app product `gratideo_lifetime` (non-consumable, US$8.99) in Play Console and App Store Connect. Until it exists the Unlock button reports "store product is not set up yet"; the 7-day trial still works.
- Replace the launcher icon (`flutter_launcher_icons` is the quick way).
- iOS: add `UIBackgroundModes: audio` to `ios/Runner/Info.plist` for the soundscape, and `NSUserNotificationsUsageDescription` style strings are not needed; notifications prompt on first schedule.
- Store copy: describe 432 Hz and binaural as sound design only.

## Not in this build yet

- Home-screen widget (native Glance / WidgetKit), recorded-voice confessions, encrypted backup, app lock. All planned for v1.1.
- Verse set is 385 verses (about 13 months without a repeat), not 730 yet.
