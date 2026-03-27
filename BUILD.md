# 🔨 构建指南

本文档说明如何在本地与 GitHub Actions 中构建随礼记。

---

## 📋 前置要求

- **Flutter SDK**：3.2.0 或更高版本
- **Git**：用于克隆仓库
- **Android**：Android Studio / Android SDK（API 21+）
- **Windows**：Visual Studio 2022（含 C++ 桌面开发工具）
- **iOS**：macOS + Xcode 14+ + CocoaPods

---

## 🚀 快速开始

```bash
git clone https://github.com/final00000000/Gift_Ledger.git
cd Gift_Ledger
flutter pub get
flutter doctor
```

---

## 📦 Android 构建

### 关键规则

- **正式发布只产出两个 split APK**
- **仅保留 `armeabi-v7a` / `arm64-v8a`**
- **不再发布 `x86 / x86_64 / universal.apk`**
- 本地与 CI 都遵循同一 ABI 约束
- `android/app/build.gradle` 已通过 `abiFilters` 限定为：
  - `armeabi-v7a`
  - `arm64-v8a`

### 本地构建：按 ABI 拆分 APK

```bash
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

输出：

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

### 本地构建：AAB

```bash
flutter build appbundle --release
```

### 发布产物命名约定

GitHub Actions `publish-updates.yml` 会产出：

- `gift_ledger-<channel>-android-v<version>-build<build>-armeabi-v7a.apk`
- `gift_ledger-<channel>-android-v<version>-build<build>-arm64-v8a.apk`

说明：

- update manifest 顶层 `downloadUrl` 固定指向 `arm64-v8a.apk`
- 新版客户端优先读取 manifest 中的 `variants`，按设备 ABI 下载对应 split APK
- 旧版客户端若只认识顶层 `downloadUrl`，会默认拿到 arm64 包，因此**不再承诺兼容旧的 universal 更新链路**

---

## 🪟 Windows 构建

### 发布版本

```bash
flutter build windows --release
```

输出：`build/windows/x64/runner/Release/`

### 打包为安装器

```bash
flutter build windows --release
iscc ^
  /DAppVersion=1.3.2 ^
  /DAppBuild=1030299 ^
  /DAppChannel=stable ^
  /DOutputBaseName=gift_ledger-stable-windows-v1.3.2-build1030299-setup ^
  windows/installer/GiftLedger.iss
```

---

## 🔄 Android / Windows 内置更新发布

### manifest 地址

```text
https://raw.githubusercontent.com/final00000000/Gift_Ledger/master/releases/update-manifest.json
```

### 工作流

```text
.github/workflows/publish-updates.yml
```

职责：

1. 构建 Android split APK（仅 `armeabi-v7a` / `arm64-v8a`）
2. 构建 Windows 安装器
3. 上传 GitHub Release 资产
4. 生成并提交 `releases/update-manifest.json`
5. 为 Android 写入 `variants`，让客户端按 ABI 下载对应安装包

### 本地生成 manifest

```bash
python tool/generate_update_manifest.py   --input tool/release/update_release_matrix.sample.json   --output releases/update-manifest.json
```

---

## 🌐 Web 构建

```bash
flutter build web --release
```

输出：`build/web/`

---

## 🍎 iOS 构建

> **注意**：iOS 安装包仅支持在 macOS + Xcode 环境中本地构建并签名导出。

### 本地无签名校验构建

```bash
flutter pub get
flutter build ios --release --no-codesign
```

---

## 📝 版本号规则

版本与 build number 的填写规则见：

```text
docs/RELEASE_VERSION_RULES.md
```

重点：

- `pubspec.yaml` 始终保存当前 stable 版本
- Android `versionCode` 不跟 GitHub Actions run number 绑定
- beta 发布必须填写完整 `release_tag`

---

## 🔧 常见问题

### Android 构建后为什么只有两个 APK？

因为当前正式发布只保留：

- `armeabi-v7a`
- `arm64-v8a`

`x86 / x86_64 / universal.apk` 已从正式发布链路中移除。

---

## 📄 相关文档

- 中文构建说明：`BUILD.md`
- 英文构建说明：`docs/BUILD_EN.md`
- 版本规则：`docs/RELEASE_VERSION_RULES.md`
