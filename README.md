# 📱 随礼记 - 礼金收支追踪管理

<div align="center">

![版本](https://img.shields.io/badge/版本-1.0.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.2.0-02569B?logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![平台](https://img.shields.io/badge/平台-Android%20%7C%20iOS%20%7C%20Web-lightgrey)

一款简洁优雅的礼金收支管理应用，帮助你轻松记录和追踪人情往来

[English](./README_EN.md) | 简体中文

</div>

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

### 首页
![首页](screenshots/home.jpg)

### 添加记录
![添加记录](screenshots/add_record.jpg)

### 数据统计
![统计](screenshots/statistics.jpg)

### 统计详情
![统计详情](screenshots/statistics_details.jpg)

### 设置
![设置](screenshots/settings.jpg)

---

## 🚀 快速开始

### 环境要求

- **Flutter SDK**: 3.2.0 或更高版本
- **Dart SDK**: 2.18.0 或更高版本

#### Android
- Android SDK: API 21 (Android 5.0) 或更高
- Java 17 或更高版本

#### iOS
- Xcode 14.0 或更高版本
- CocoaPods 1.11.0 或更高版本
- macOS 12.0 或更高版本

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
   
   **iOS**
   ```bash
   flutter build ios --release
   ```

---

## 🏗️ 项目结构

```
gift_money_tracker/
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
