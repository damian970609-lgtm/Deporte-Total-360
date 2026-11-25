# ShadowKeys project instructions

## Product target
- Native Android application for GTA San Andreas mobile, targeting Android 15 and the user's reported Rockstar build 2.11.311.
- Main package: com.damian.shadowkeys.
- Do not claim 2.11.311 compatibility until a real-device test confirms that GTA consumes injected key events.

## Architecture
- Kotlin Android app; no Flutter.
- Cheat definitions live in app/src/main/java/com/damian/shadowkeys/data/CheatCatalog.kt.
- Key mapping is pure Kotlin in InputKeyMapper.kt and must remain unit-tested.
- Global key injection is only attempted from the Shizuku UserService running with an authorized ADB/root identity. Never fall back to Runtime.exec from the normal app process and never report success unless the UserService returns successful command exit statuses.
- Overlay windows must remain non-focusable so the foreground game retains keyboard focus.
- The app must provide copy-to-clipboard behavior when injection is unavailable.

## Safety and permissions
- Explain that Shizuku started through Wireless debugging or a rooted Sui setup is required for global key injection on a normal Android app.
- Do not request Accessibility access unless a specific implemented feature genuinely requires it.
- Never request root, disable Play Protect, or ask the user to weaken Android package verification.
- Do not add analytics, ads, network collection, or unrelated permissions.

## Build and verification
- CI: .github/workflows/shadowkeys-android.yml
- Run: gradle :app:testDebugUnitTest :app:assembleDebug
- Tests must validate the 83 mobile cheat entries, uniqueness, category totals, and keycode mapping.
- Keep the app targetSdk at 35 unless a documented compatibility reason requires a change.
