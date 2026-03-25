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

### 打包为 EXE 安装器（推荐）

```bash
# 1. 先构建 Windows Release
flutter build windows --release

# 2. 使用 Inno Setup 脚本生成安装器（示例为 stable）
# 脚本位置：windows/installer/GiftLedger.iss
# 需要在 Windows 环境安装 Inno Setup 6
iscc ^
  /DAppVersion=1.2.8 ^
  /DAppBuild=8 ^
  /DAppChannel=stable ^
  /DOutputBaseName=gift_ledger-stable-windows-v1.2.8-build8-setup ^
  windows/installer/GiftLedger.iss
```

推荐产物：`gift_ledger-<channel>-windows-v<version>-build<build>-setup.exe`

> 说明：Windows 发布不再以 ZIP 作为主分发格式，优先使用 EXE 安装器，
> 便于后续 App 内更新直接拉起安装流程。

---

## 🔄 Android / Windows 内置更新发布

### 固定 manifest 地址

客户端固定读取以下地址：

```text
https://raw.githubusercontent.com/final00000000/Gift_Ledger/master/releases/update-manifest.json
```

### manifest 结构约定

- 发布侧统一生成 `releases/update-manifest.json`
- 支持两个通道：`stable`、`beta`
- 支持两个平台：`android`、`windows`
- 目标键统一格式：

```text
<resolvedTargetChannel>@<platform>@<version>@<buildNumber>
```

### 本地生成 manifest

```bash
python tool/generate_update_manifest.py \
  --input tool/release/update_release_matrix.sample.json \
  --output releases/update-manifest.json
```

可继续做 JSON 校验：

```bash
python -m json.tool releases/update-manifest.json > nul
```

### GitHub Actions 发布工作流

工作流文件：

```text
.github/workflows/publish-updates.yml
```

职责：

1. 构建 Android APK
2. 构建 Windows Release + EXE 安装器
3. 计算产物 sha256
4. 上传 GitHub Release 资产
5. 生成并提交 `releases/update-manifest.json`

### 通道规则

- `stable`：默认公开发布通道
- `beta`：手动开启的测试通道
- beta 用户优先接收 beta；若无更高 beta，则回退 stable

### 发布前最小检查清单

- `pubspec.yaml` 版本号已更新
- Android / Windows 产物命名符合约定
- manifest 中 `version` / `buildNumber` / `downloadUrl` / `sha256` 正确
- `releases/update-manifest.json` 可被 Raw URL 直接访问
- 设置页切换 stable / beta 后，客户端行为符合预期

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
