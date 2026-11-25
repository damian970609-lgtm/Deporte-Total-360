# ShadowKeys native no-op test

This directory builds an ARM64 Android shared library named libShadowKeys.so.

Safety properties:
- It does not open, patch, or write to GTA files.
- It does not read or write game-process memory.
- It does not hook game functions or activate cheats.
- JNI_OnLoad only writes an informational Android log entry.
- The exported JNI probe returns a fixed status string.

Important: a successful build proves only that the native test library compiles for ARM64. It does not prove that GTA loads it. Android will not automatically load an arbitrary shared library copied beside a game library. A separate, verified bootstrap/loader in a disposable GTA clone is still required before an in-game test is possible.

Target ABI: arm64-v8a.
