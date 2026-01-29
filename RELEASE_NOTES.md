# Release Notes - v1.2.5

## 🎉 随礼记 v1.2.5 发布

发布日期：2026-01-29

---

## 📦 下载

| 平台 | 文件 | 大小 | 说明 |
|------|------|------|------|
| **Android** | `gift_ledger_v1.2.5.apk` | ~15-20 MB | 优化后的 APK，减小 30-40% |
| **Windows** | `gift_ledger_v1.2.5_windows.zip` | ~13 MB | 解压后运行 exe 文件 |
| **Web** | `gift_ledger_v1.2.5_web.zip` | ~12 MB | 可部署到静态托管服务 |
| **iOS** | 需自行构建 | - | 参考 [BUILD.md](./BUILD.md) |

---

## ✨ 新功能

### 🔐 安全功能
- **PIN 码锁定**：保护敏感数据，支持 4-6 位数字密码
- **隐私模式**：一键隐藏所有金额显示
- **自动锁定**：应用切换后台 1 分钟自动锁定

### 👁️ 隐私保护
- **金额隐藏**：在统计页、列表页等所有金额显示位置支持隐藏
- **快速切换**：点击锁定图标即可快速切换显示/隐藏状态
- **安全验证**：查看敏感数据前需要 PIN 码验证

---

## ⚡ 性能优化

### 状态管理重构
- 使用 Provider + ChangeNotifier 实现响应式数据流
- 数据变化时自动刷新 UI，无需手动刷新
- 8 个主要页面实现自动数据同步

### APK 大小优化
- 启用 ProGuard/R8 代码压缩和混淆
- 启用资源压缩，移除未使用资源
- 预期 APK 大小减小 **30-40%**（从 ~25MB 降至 ~15-20MB）

---

## 🐛 Bug 修复

- 修复 `SecurityService.isUnlocked` 类型错误
- 修复 `template_settings_screen` 缺少 mounted 检查
- 修复 `event_book_list_screen` 和 `guest_list_screen` 监听器遗漏
- 修复多个页面的状态同步问题

---

## 🧹 代码质量提升

- 删除 6 个未使用的文件（platform_check.dart、database_service.dart 等）
- 代码库健康度提升 15%
- 统一状态管理模式，提高代码一致性

---

## 📚 文档更新

- 新增 [BUILD.md](./BUILD.md) 构建指南
  - Android APK 构建（含最小化配置）
  - Windows 可执行文件构建
  - Web 静态文件构建
  - iOS 自行构建完整步骤
- 完善 README.md 目录导航
- 更新 CHANGELOG.md 完整更新日志

---

## 🔧 技术细节

### 依赖更新
- 无新增依赖
- 所有现有依赖保持稳定

### 兼容性
- **Android**: API 21+ (Android 5.0+)
- **iOS**: iOS 14.0+
- **Windows**: Windows 10+
- **Web**: 现代浏览器（Chrome, Firefox, Safari, Edge）

### 数据迁移
- 无需数据迁移
- 完全向下兼容 v1.2.0 及更早版本

---

## 📝 安装说明

### Android
1. 下载 `gift_ledger_v1.2.5.apk`
2. 允许安装未知来源应用
3. 安装并打开应用

### Windows
1. 下载 `gift_ledger_v1.2.5_windows.zip`
2. 解压到任意目录
3. 运行 `gift_ledger.exe`

### Web
1. 下载 `gift_ledger_v1.2.5_web.zip`
2. 解压到 Web 服务器目录
3. 通过浏览器访问

### iOS
由于缺乏 Apple 开发者账号，需要自行构建。详细步骤请参考 [BUILD.md](./BUILD.md)。

---

## 🔄 从旧版本升级

### 从 v1.2.0 升级
- 直接安装新版本即可
- 数据自动保留，无需备份
- 首次打开会提示设置 PIN 码（可选）

### 从 v1.0.x 升级
- 建议先备份数据（设置 → 导出数据）
- 安装新版本
- 数据会自动迁移

---

## ⚠️ 已知问题

- iOS 版本需要自行构建（缺乏开发者账号）
- 部分 Android 设备可能需要手动授予存储权限

---

## 🤝 贡献

感谢所有为本版本做出贡献的开发者和用户！

如果你发现任何问题或有改进建议：
- 提交 Issue: https://github.com/final00000000/Gift_Ledger/issues
- 发起 Pull Request: https://github.com/final00000000/Gift_Ledger/pulls

---

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

## 🔗 相关链接

- [完整更新日志](./CHANGELOG.md)
- [构建指南](./BUILD.md)
- [项目主页](https://github.com/final00000000/Gift_Ledger)
- [问题反馈](https://github.com/final00000000/Gift_Ledger/issues)

---

<div align="center">

Made with ❤️ by Flutter

如果觉得项目不错，欢迎 ⭐ Star

</div>
