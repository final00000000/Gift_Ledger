# 业务关系图｜随礼记（Gift Ledger）

```mermaid
erDiagram
  GUEST ||--o{ GIFT : "往来记录"
  EVENT_BOOK ||--o{ GIFT : "归属"
  GIFT }o--|| GIFT : "回礼关联"
  SETTINGS ||--|| APP : "偏好"
  TEMPLATE ||--o{ NOTIFICATION : "文案"
```

## 说明
- **GUEST**：联系人
- **GIFT**：礼金记录
- **EVENT_BOOK**：活动簿（婚礼/满月/乔迁等自定义活动）
- **SETTINGS**：用户设置（隐私/统计口径等）
- **TEMPLATE/NOTIFICATION**：提醒话术与通知

## 关键流程

### 1. 新增礼金记录
```mermaid
flowchart TD
  A[首页-记一笔] --> B[填写联系人/金额/事由/日期]
  B --> C{是否选择活动簿}
  C -- 否 --> D[保存礼金记录]
  C -- 是 --> E[关联活动簿ID]
  E --> D
  D --> F[刷新首页与统计]
```

### 2. 活动簿批量录入
```mermaid
flowchart TD
  A[活动簿列表] --> B[新建活动簿]
  B --> C[填写名称/类型/日期/备注]
  C --> D[保存并进入详情]
  D --> E[批量新增礼金]
  E --> F[保存多条记录]
```

### 3. 年度统计筛选
```mermaid
flowchart TD
  A[进入统计页] --> B[选择年份/全部]
  B --> C[过滤礼金列表]
  C --> D[生成分类图表]
  D --> E[点击分类]
  E --> F[Orbit详情]
```

### 4. 还礼提醒
```mermaid
flowchart TD
  A[保存收礼记录] --> B[生成还礼期限]
  B --> C[待还列表]
  C --> D{每月提醒开关}
  D -- 开启 --> E[推送待还Top3]
  D -- 关闭 --> F[不推送]
```

### 5. 首页金额隐私
```mermaid
flowchart TD
  A[设置-显示首页金额] --> B{开关}
  B -- 开启 --> C[显示真实金额]
  B -- 关闭 --> D[显示***]
```
