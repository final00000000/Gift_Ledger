# 🔨 Build Guide

This guide shows how to build Gift Ledger on each platform.

---

## ✅ Requirements

- **Flutter SDK**: 3.2.0+
- **Dart SDK**: Bundled with Flutter
- **Git**: For cloning the repo

### Platform-specific

| Platform | Extra Requirements |
|----------|--------------------|
| **Android** | Android Studio / Android SDK (API 21+) |
| **Windows** | Visual Studio 2022 with C++ desktop workload |
| **Web** | Chrome (for debugging) |
| **iOS** | macOS + Xcode 14+ + CocoaPods |

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

```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

---

## 🪟 Windows

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/`

---

## 🌐 Web

```bash
flutter build web --release
```

Output: `build/web/`

---

## 🍎 iOS

```bash
cd ios
pod install
cd ..
flutter build ios --release
```

Open in Xcode for signing: `ios/Runner.xcworkspace`

---

For more details, see the Chinese guide: [BUILD.md](./BUILD.md)
