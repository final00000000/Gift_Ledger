# 🔨 Build Guide

This document explains how to build Gift Ledger locally and in GitHub Actions.

---

## ✅ Requirements

- **Flutter SDK**: 3.2.0+
- **Git**
- **Android**: Android Studio / Android SDK (API 21+)
- **Windows**: Visual Studio 2022 with C++ desktop workload
- **iOS**: macOS + Xcode 14+ + CocoaPods

---

## 🚀 Quick Start

```bash
git clone https://github.com/final00000000/Gift_Ledger.git
cd Gift_Ledger
flutter pub get
flutter doctor
```

---

## 🤖 Android

### Rules

- Official releases now publish **split APKs only**
- Only **armeabi-v7a** and **arm64-v8a** are kept
- **x86 / x86_64 / universal.apk are no longer published**
- The same ABI rule applies to local builds and GitHub Actions

### Split APKs per ABI

```bash
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

Outputs:

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

### Release artifact naming

`publish-updates.yml` publishes:

- `gift_ledger-<channel>-android-v<version>-build<build>-armeabi-v7a.apk`
- `gift_ledger-<channel>-android-v<version>-build<build>-arm64-v8a.apk`

Notes:

- the top-level Android `downloadUrl` in the manifest points to `arm64-v8a.apk`
- newer clients read Android `variants` from the manifest and download the matching ABI package
- older clients that only understand the top-level `downloadUrl` are **not guaranteed** to stay compatible with the removed universal flow

---

## 🪟 Windows

```bash
flutter build windows --release
```

Output:

- `build/windows/x64/runner/Release/`

---

## 🔄 In-app update publishing

Manifest URL:

```text
https://raw.githubusercontent.com/final00000000/Gift_Ledger/master/releases/update-manifest.json
```

Workflow:

```text
.github/workflows/publish-updates.yml
```

It will:

1. build Android split APKs for `armeabi-v7a` and `arm64-v8a`
2. build the Windows installer
3. upload GitHub Release assets
4. generate `releases/update-manifest.json`
5. write Android `variants` so the app can resolve the correct ABI package

---

## 🌐 Web

```bash
flutter build web --release
```

---

## 🍎 iOS

> iOS installable packages are only supported through local build and signing on macOS with Xcode.

### Local unsigned verification

```bash
flutter pub get
flutter build ios --release --no-codesign
```
