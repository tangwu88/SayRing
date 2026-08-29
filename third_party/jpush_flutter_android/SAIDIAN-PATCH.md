# Saydian compatibility patch

This directory is a source copy of `jpush_flutter_android` version `1.0.2`.
Its upstream license is preserved in `LICENSE`.
The original package archive SHA-256 recorded at import time is
`d2bae547aefb2ff5acf28badaf115bb358e9244b6acef84625d8db0228bbc0b2`.

The only source-level compatibility change is in
`android/proguard-rules.pro`: application-wide R8 directives
(`-dontoptimize`, `-dontpreverify`, and `-ignorewarnings`) were removed from
the Android library consumer rules because current Android Gradle Plugin
versions reject global directives in consumer configuration files.

The Gradle configuration also accepts JPush and vendor-channel values directly
from protected CI environment variables. This avoids ever writing production
credentials into the tracked root `pubspec.yaml`. Pubspec configuration remains
available as an upstream-compatible local fallback.

All dependency versions, Dart APIs, Kotlin sources, Android manifests, and
targeted keep/dontwarn rules remain upstream 1.0.2.
