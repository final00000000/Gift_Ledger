# Git 提交规则

## 禁止添加 Co-Authored-By

提交代码时 **禁止** 添加以下内容：

```
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

或任何类似的 AI 署名标记。

## 提交信息格式

使用标准的 Conventional Commits 格式：

```
<type>: <description>

[optional body]
```

类型包括：
- feat: 新功能
- fix: 修复
- docs: 文档
- refactor: 重构
- chore: 杂项
- release: 发布版本

不要在提交信息中提及 Claude 或 AI 辅助。
