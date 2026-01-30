# 📱 随礼记 - 礼金收支追踪管理

<div align="center">

![版本](https://img.shields.io/badge/版本-1.2.6-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.2.0-02569B?logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![平台](https://img.shields.io/badge/平台-Android%20%7C%20Windows%20%7C%20Web%20%7C%20iOS-lightgrey)

一款简洁优雅的礼金收支管理应用，帮助你轻松记录和追踪人情往来

[English](./README_EN.md) | 简体中文

</div>

---

## 📑 目录

- [下载安装](#-下载安装)
- [功能特性](#-功能特性)
- [应用截图](#-应用截图)
- [更新日志](#-更新日志)
- [快速开始](#-快速开始)
  - [环境要求](#环境要求)
  - [安装步骤](#安装步骤)
  - [iOS 自行构建](#ios-自行构建)
- [构建指南](#-构建指南)
- [项目结构](#-项目结构)
- [核心依赖](#-核心依赖)
- [技术栈](#-技术栈)
- [开源协议](#-开源协议)
- [反馈与支持](#-反馈与支持)

---

## 📥 下载安装

| 平台 | 下载链接 | 说明 |
|------|----------|------|
| **Android** | [📦 APK 下载](https://github.com/final00000000/Gift_Ledger/releases/latest) | 直接安装 APK 文件 |
| **Windows** | [📦 ZIP 下载](https://github.com/final00000000/Gift_Ledger/releases/latest) | 解压后运行 `gift_ledger.exe` |
| **Web** | [📦 ZIP 下载](https://github.com/final00000000/Gift_Ledger/releases/latest) | 可部署到任何静态托管服务 |
| **iOS** | 暂无预编译版本 | 需自行构建（见下方说明）|

> [!NOTE]
> **iOS 用户须知**  
> 由于缺乏 Apple 开发者账号，暂时无法提供预编译的 IPA 文件。  
> 您可以参考下方 [iOS 自行构建](#ios-自行构建) 章节，使用 Xcode 在您的设备上构建和安装应用。

> [!TIP]
> **Web 部署建议**  
> Web 版本可部署到：GitHub Pages、Vercel、Netlify、Cloudflare Pages 等免费静态托管服务，或您自己的 Web 服务器。

---

## ✨ 功能特性

### 📊 数据统计
- **收支概览**：一目了然的收支对比卡片
- **实时余额**：动态计算收支差额
- **可视化图表**：直观展示收支趋势

### 📝 记录管理
- **快速记账**：简洁的记账界面，支持自定义金额输入
- **智能建议**：根据历史记录提供联系人建议
- **灵活分类**：支持婚礼、满月、乔迁、生日、丧事、过年等多种事由
- **关系标签**：朋友、同事、亲戚、同学等关系分类
- **农历日期**：支持农历日历选择，方便记录传统节日

### 👥 人际管理
- **联系人管理**：自动维护礼金往来的联系人列表
- **往来追踪**：清晰记录每个人的收礼和送礼金额
- **还礼提醒**：智能标注待还礼、已还礼状态
- **进度可视化**：直观显示还礼进度条

### 📱 便捷功能
- **搜索筛选**：支持按姓名、事由快速搜索
- **编辑删除**：点击记录即可编辑或删除
- **数据备份**：支持导出 Excel 和 JSON 格式
- **数据恢复**：支持导入备份文件恢复数据
- **严格验证**：防止重复导入，保护数据完整性

### 🎨 界面设计
- **现代 UI**：Material Design 3 设计语言
- **流畅动画**：精心设计的页面过渡和交互动画
- **响应式布局**：适配不同屏幕尺寸

---

## 📸 应用截图

<details>
<summary>点击展开查看应用截图</summary>

| 首页 | 添加记录 |
|:---:|:---:|
| ![首页](screenshots/home.jpg) | ![添加记录](screenshots/add_record.jpg) |

| 数据统计 | 统计详情 |
|:---:|:---:|
| ![统计](screenshots/statistics.jpg) | ![统计详情](screenshots/statistics_details.jpg) |

| 设置 |
|:---:|
| ![设置](screenshots/settings.jpg) |

</details>

---

## 📋 更新日志

### v1.2.6 (2026-01-30) 🆕
- 🔐 **密码找回**：自定义安全问题，忘记密码可重置
- 💊 **快捷操作UI**：胶囊标签样式，视觉统一
- ⌨️ **键盘适配**：弹窗键盘遮挡优化

👉 [查看完整更新日志](./CHANGELOG.md)

---

## 🚀 快速开始

### 环境要求

- **Flutter SDK**: 3.2.0 或更高版本
- **Dart SDK**: 2.18.0 或更高版本

#### Android
- Android SDK: API 21 (Android 5.0) 或更高
- Java 17 或更高版本

#### iOS (自行构建)
- Xcode 14.0 或更高版本
- CocoaPods 1.11.0 或更高版本
- macOS 12.0 或更高版本
- Apple 开发者账号 (用于真机测试)

#### Windows
- Windows 10 或更高版本
- Visual Studio 2019 或更高版本 (含 C++ 桌面开发工具)

#### Web
- 现代浏览器 (Chrome, Firefox, Safari, Edge)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/final00000000/Gift_Ledger.git
   cd Gift_Ledger
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   flutter run
   ```

4. **构建发布版本**
   
   **Android APK**
   ```bash
   flutter build apk --release
   ```
   
   **iOS** (需要 macOS 和 Xcode)
   ```bash
   flutter build ios --release
   # 构建完成后在 Xcode 中打开项目进行签名和安装
   open ios/Runner.xcworkspace
   ```
   
   **Windows**
   ```bash
   flutter build windows --release
   # 可执行文件位于: build\windows\x64\runner\Release\gift_ledger.exe
   ```
   
   **Web**
   ```bash
   flutter build web --release
   # 输出目录: build\web
   # 可部署到任何静态 Web 服务器
   ```

### iOS 自行构建

由于没有 Apple 开发者账号，iOS 版本需要您自行构建。以下是详细步骤：

#### 前置要求
- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本
- CocoaPods 1.11.0 或更高版本
- Apple ID（免费账号即可用于真机测试）

#### 构建步骤

1. **安装 CocoaPods 依赖**
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. **在 Xcode 中打开项目**
   ```bash
   open ios/Runner.xcworkspace
   ```

3. **配置签名**
   - 在 Xcode 中选择 "Runner" 项目
   - 进入 "Signing & Capabilities" 标签
   - 将 "Team" 设置为您的 Apple ID
   - Xcode 会自动处理其余配置

4. **连接设备并运行**
   - 使用 USB 连接您的 iPhone/iPad
   - 在 Xcode 顶部选择您的设备
   - 点击运行按钮 (▶️) 或按 `Cmd + R`

5. **信任开发者**
   - 首次安装需要在设备上信任开发者证书
   - 前往：设置 → 通用 → VPN 与设备管理 → 信任您的 Apple ID

> [!IMPORTANT]
> **免费 Apple ID 限制**  
> - 应用签名有效期为 7 天，过期后需重新构建安装
> - 每个 Apple ID 最多可同时签名 3 个应用
> - 如需长期使用，建议注册 Apple 开发者计划（$99/年）


---

## 🔨 构建指南

详细的构建说明请参考 [BUILD.md](./BUILD.md)，包括：
- Android APK 构建（含 APK 最小化配置）
- Windows 可执行文件构建
- Web 静态文件构建
- iOS 自行构建完整步骤
- 常见问题解决方案

---

## 🏗️ 项目结构

```
Gift_Ledger/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   ├── screens/                  # 页面
│   ├── services/                 # 业务逻辑
│   ├── widgets/                  # 自定义组件
│   └── theme/                    # 主题配置
├── android/                      # Android 平台代码
├── ios/                          # iOS 平台代码
├── assets/                       # 资源文件
└── pubspec.yaml                  # 项目配置
```

---

## 📦 核心依赖

| 依赖包 | 版本 | 用途 |
|--------|------|------|
| sqflite | ^2.3.0 | 本地数据库存储 |
| path_provider | ^2.1.1 | 文件路径获取 |
| intl | ^0.20.2 | 国际化和日期格式化 |
| file_picker | ^8.0.0 | 文件选择器 |
| excel | ^4.0.3 | Excel 文件读写 |
| share_plus | ^8.0.0 | 文件分享 |

---

## 🛠️ 技术栈

- **框架**: Flutter 3.2.0+
- **语言**: Dart 2.18.0+
- **数据库**: SQLite (sqflite)
- **UI 设计**: Material Design 3
- **数据导出**: Excel / JSON

---

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源

---

## 💬 反馈与支持

如果你有任何问题或建议：

- 🐛 [提交 Issue](https://github.com/final00000000/Gift_Ledger/issues)
- ⭐ 如果这个项目对你有帮助，请给我们一个 Star！

---

<div align="center">
  
### ⭐ 如果觉得项目不错，欢迎 Star ⭐

Made with ❤️ by Flutter

</div>
