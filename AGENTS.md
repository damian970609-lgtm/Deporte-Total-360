# ShadowKeys project instructions

## Product target
- Native Android application for classic GTA San Andreas Mobile, targeting Android 15 and the user's reported Rockstar build 2.11.311.
- Main package: com.damian.shadowkeys.
- Do not claim 2.11.311 compatibility until a real-device test confirms that GTA consumes injected key events.

## Architecture
- Kotlin Android app; no Flutter.
- Cheat definitions live in app/src/main/java/com/damian/shadowkeys/data/CheatCatalog.kt.
- Key mapping is pure Kotlin in InputKeyMapper.kt and must remain unit-tested.
- Global key injection uses the embedded Kadb client to pair with this same device's Android Wireless Debugging (adbd) service. No Shizuku app or root is required, but explicit user pairing in Developer options is required.
- Never run input commands from the normal application UID. Only the embedded ADB shell identity may execute the internally generated, whitelisted input keyevent sequence. Never accept arbitrary shell commands from UI or network.
- Overlay windows must remain non-focusable so the foreground game retains keyboard focus.
- The app must provide copy-to-clipboard behavior when ADB is unavailable.

## Safety and permissions
- Explain the one-time Wireless Debugging pairing requirement and that the shell authorization is powerful while active.
- Do not request Accessibility access or root.
- Do not disable Play Protect or ask the user to weaken Android package verification.
- Do not add analytics, ads, network collection, or unrelated permissions.
- Do not read, modify, or delete GTA installation files or game saves.

## Build and verification
- CI: .github/workflows/shadowkeys-android.yml
- Run: gradle :app:testDebugUnitTest :app:assembleDebug
- Tests must validate the exact 83 mobile cheat codes, uniqueness, category totals, and keycode mapping.
- Keep app targetSdk at 35 unless a documented compatibility reason requires a change.
