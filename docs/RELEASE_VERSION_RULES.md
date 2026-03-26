# 发布版本填写规则

本文档说明 `pubspec.yaml`、GitHub Actions `publish-updates.yml` 手动发布参数，以及 Android `versionCode` 的填写规则。

---

## 1. 规则目标

当前版本规则的目标是：

- `versionCode` 不再跟 GitHub Actions 的 run number 绑定
- 同一核心版本下，**stable 永远高于 beta**
- `patch >= 10` 时，`versionCode` 仍保持单调递增
- 避免手动选择 `beta` 却发布出错误版本

---

## 2. Android versionCode 规则

### 2.1 计算公式

```text
versionCode = major * 1_000_000
            + minor * 10_000
            + patch * 100
            + stage
```

其中：

- `stable`：`stage = 99`
- `beta.N`：`stage = 01..98`

### 2.2 示例

- `1.3.2` → `1030299`
- `1.3.2-beta.1` → `1030201`
- `1.3.2-beta.2` → `1030202`
- `1.3.10` → `1031099`
- `1.4.0` → `1040099`

### 2.3 约束

- `minor` 必须 `< 100`
- `patch` 必须 `< 100`
- `beta` 序号必须在 `1..98`
- 当前只支持 `stable` 与 `beta.N`

---

## 3. pubspec.yaml 如何填写

### 3.1 stable 版本

`pubspec.yaml` 中始终填写**当前主线 stable 版本**：

```yaml
version: 1.3.2+1030299
```

含义：

- `1.3.2` 是 `versionName`
- `1030299` 是 stable 的 `versionCode`

### 3.2 beta 版本

beta 发布时，**不需要把 `pubspec.yaml` 改成 beta**。

例如要发 `1.3.2-beta.2`：

- `pubspec.yaml` 仍然保持：

```yaml
version: 1.3.2+1030299
```

- 真正的 beta 版本号与 build number 由 GitHub Actions 发布参数覆盖

这样可以保证：

- 主线文件始终表达当前 stable 目标版本
- beta 包仍能得到正确的 `versionName/versionCode`

---

## 4. GitHub Actions 手动发布如何填写

工作流文件：

```text
.github/workflows/publish-updates.yml
```

### 4.1 发布 stable

建议填写：

- `channel`: `stable`
- `release_tag`: 留空，或填写 `v1.3.2`
- `release_notes`: 按需填写

示例：

```text
channel = stable
release_tag = v1.3.2
release_notes = 修复更新弹窗与下载流程问题
```

### 4.2 发布 beta

必须填写完整的 prerelease tag：

- `channel`: `beta`
- `release_tag`: **必须**是 `v1.3.2-beta.1`、`v1.3.2-beta.2` 这种格式
- `release_notes`: 按需填写

示例：

```text
channel = beta
release_tag = v1.3.2-beta.2
release_notes = 测试包：验证应用内更新链路
```

### 4.3 beta 禁止的错误填法

下面这种写法会直接失败：

```text
channel = beta
release_tag = 留空
```

原因：系统不会再自动猜测 `-beta` 或 `.1`，避免发布出语义错误的版本。

---

## 5. 发布后产物命名示例

### Android

```text
gift_ledger-stable-android-v1.3.2-build1030299.apk
gift_ledger-beta-android-v1.3.2-beta.2-build1030202.apk
```

### Windows

```text
gift_ledger-stable-windows-v1.3.2-build1030299-setup.exe
gift_ledger-beta-windows-v1.3.2-beta.2-build1030202-setup.exe
```

---

## 6. 为什么 stable 要用 99

如果同一核心版本下 beta 比 stable 大，例如：

- `1.3.2-beta.2 = 1322`
- `1.3.2 = 1320`

那么 Android 会把 stable 视为**降级安装**。

现在改成：

- `1.3.2-beta.2 = 1030202`
- `1.3.2 = 1030299`

这样 stable 永远大于同核心 beta，用户从 beta 升到 stable 不会再失败。

---

## 7. 发布前检查清单

发布前请确认：

- `pubspec.yaml` 中 stable 版本号已更新
- `pubspec.yaml` 中 build number 符合公式
- stable 发布时，`release_tag` 与 stable 版本一致
- beta 发布时，`release_tag` 使用完整 prerelease 格式
- `release_notes` 已填写本次更新说明
- 产物名称中的 `version` / `build` 与目标版本一致

---

## 8. 快速对照表

### stable

```text
pubspec.yaml  = 1.3.2+1030299
channel       = stable
release_tag   = v1.3.2（可留空）
产物版本      = 1.3.2 / 1030299
```

### beta

```text
pubspec.yaml  = 1.3.2+1030299
channel       = beta
release_tag   = v1.3.2-beta.2（必填）
产物版本      = 1.3.2-beta.2 / 1030202
```



