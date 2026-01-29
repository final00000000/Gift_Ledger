# 🔨 构建指南

本文档说明如何为不同平台构建随礼记应用。

---

## 📋 前置要求

- **Flutter SDK**: 3.2.0 或更高版本
- **Dart SDK**: 随 Flutter 一起安装
- **Git**: 用于克隆仓库

### 平台特定要求

| 平台 | 额外要求 |
|------|----------|
| **Android** | Android Studio / Android SDK (API 21+) |
| **Windows** | Visual Studio 2022 (含 C++ 桌面开发工具) |
| **Web** | Chrome 浏览器（用于调试） |
| **iOS** | macOS + Xcode 14+ + CocoaPods |

---

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/final00000000/Gift_Ledger.git
cd Gift_Ledger
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 检查环境

```bash
flutter doctor
```

确保所有必需的工具都已正确安装。

---

## 📦 Android 构建

### 调试版本

```bash
flutter build apk --debug
```

输出位置：`build/app/outputs/flutter-apk/app-debug.apk`

### 发布版本（最小化 APK）

```bash
# 构建优化的 APK（启用代码压缩和混淆）
flutter build apk --release --shrink

# 或构建 App Bundle（推荐用于 Google Play）
flutter build appbundle --release
```

输出位置：
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### APK 大小优化说明

项目已配置以下优化：
- ✅ **代码压缩**：移除未使用的代码
- ✅ **资源压缩**：移除未使用的资源
- ✅ **代码混淆**：使用 ProGuard/R8 混淆代码
- ✅ **拆分 ABI**：为不同 CPU 架构生成单独的 APK

预期 APK 大小：**15-20 MB**（单架构）

---

## 🪟 Windows 构建

### 发布版本

```bash
flutter build windows --release
```

输出位置：`build/windows/x64/runner/Release/`

### 打包为 ZIP

```bash
# Windows (PowerShell)
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath gift_ledger_windows.zip

# Linux/macOS
cd build/windows/x64/runner/Release
zip -r ../../../../../gift_ledger_windows.zip *
```

---

## 🌐 Web 构建

### 发布版本

```bash
flutter build web --release
```

输出位置：`build/web/`

### 本地测试

```bash
# 使用 Python 启动本地服务器
cd build/web
python -m http.server 8000

# 或使用 Node.js
npx serve
```

访问：`http://localhost:8000`

### 部署到静态托管

构建产物（`build/web/` 目录）可直接部署到：
- GitHub Pages
- Vercel
- Netlify
- Cloudflare Pages
- 任何静态文件托管服务

---

## 🍎 iOS 构建

> **注意**：iOS 构建需要 macOS 系统和 Apple 开发者账号（用于真机安装）。

### 1. 安装 CocoaPods 依赖

```bash
cd ios
pod install
cd ..
```

### 2. 使用 Xcode 构建

```bash
# 打开 Xcode 项目
open ios/Runner.xcworkspace
```

在 Xcode 中：
1. 选择你的开发团队（Signing & Capabilities）
2. 连接 iOS 设备
3. 选择目标设备
4. 点击 Run 或 Archive

### 3. 命令行构建（需要配置签名）

```bash
flutter build ios --release
```

输出位置：`build/ios/iphoneos/Runner.app`

### 生成 IPA（需要开发者账号）

在 Xcode 中：
1. Product → Archive
2. 等待归档完成
3. Distribute App → Ad Hoc / App Store
4. 导出 IPA 文件

---

## 🔧 常见问题

### Android 构建失败

**问题**：`Execution failed for task ':app:lintVitalRelease'`

**解决**：在 `android/app/build.gradle` 中添加：
```gradle
android {
    lintOptions {
        checkReleaseBuilds false
    }
}
```

### Windows 构建失败

**问题**：缺少 Visual Studio 工具

**解决**：
1. 安装 Visual Studio 2022
2. 勾选"使用 C++ 的桌面开发"工作负载
3. 重新运行 `flutter doctor`

### iOS 构建失败

**问题**：`CocoaPods not installed`

**解决**：
```bash
sudo gem install cocoapods
```

### Web 构建后无法加载

**问题**：CORS 错误或资源加载失败

**解决**：
- 确保使用 HTTP 服务器（不要直接打开 index.html）
- 检查 `web/index.html` 中的 base href 配置

---

## 📝 版本号管理

版本号在 `pubspec.yaml` 中定义：

```yaml
version: 1.2.5+5
```

格式：`主版本.次版本.修订号+构建号`

修改版本号后，重新构建即可应用新版本。

---

## 🤝 贡献

如果你在构建过程中遇到问题或有改进建议，欢迎：
- 提交 Issue
- 发起 Pull Request
- 更新本文档

---

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。
