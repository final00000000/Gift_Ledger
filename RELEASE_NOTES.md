# Release Notes - v1.3.3

## 🎉 随礼记 v1.3.3

发布日期：2026-03-29

---

## ✨ 更新内容

- 💾 `feat(backup)`: JSON 导出升级为完整备份，新增活动簿与更多字段的导入恢复
- ⚙️ `feat(default-entry)`: 单条新增与批量新增统一遵循默认收礼 / 送礼设置
- 🔐 `fix(security)`: PIN 与密保答案增加分级锁定与失败控制
- 📊 `fix(statistics)`: 修复统计页年份筛选在窄屏下的溢出问题
- ℹ️ `fix(update-ui)`: 不支持应用内更新的平台改为明确展示 unsupported 状态
- 📦 `fix(android-release)`: 修复 `abiFilters` 与 split APK 发布参数冲突，恢复 Android Release 构建
- 🪟 `fix(windows-release)`: 修复 GitHub Actions 在 PowerShell 下的 Windows 构建命令续行问题
- ♻️ `refactor(app-services)`: 拆分 StorageService 职责并下沉页面计算逻辑
- 🧪 `test(flows)`: 新增覆盖主导航、新增记录、记录列表、待处理与统计筛选的关键流程测试

---

## 📦 发布产物

- Android：
  - `gift_ledger-stable-android-v1.3.3-build1030399-armeabi-v7a.apk`
  - `gift_ledger-stable-android-v1.3.3-build1030399-arm64-v8a.apk`
- Windows：`gift_ledger-stable-windows-v1.3.3-build1030399-setup.exe`

---

👉 [查看完整更新日志](./CHANGELOG.md)
