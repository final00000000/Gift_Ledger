# 网络 API 接入使用指南

## 📦 已安装的依赖

```yaml
dependencies:
  dio: ^5.7.0                   # HTTP 客户端
  flutter_riverpod: ^2.6.1      # 状态管理
```

## 🏗️ 架构概览

```
lib/
├── models/
│   ├── api_response.dart          # API 响应模型
│   ├── gift.dart                  # 礼金模型（已添加 JSON 序列化）
│   ├── guest.dart                 # 联系人模型（已添加 JSON 序列化）
│   └── event_book.dart            # 活动簿模型（已添加 JSON 序列化）
├── services/
│   ├── api_service.dart           # API 服务层（Gift/Guest/EventBook/Statistics）
│   └── api_interceptors.dart     # Dio 拦截器（Token/Loading/Error）
├── providers/
│   └── api_providers.dart         # Riverpod Providers（数据层）
└── widgets/
    └── loading_overlay.dart       # Loading/Error UI 组件
```

## 🚀 快速开始

### 1. 配置 API 地址

编辑 `lib/services/api_service.dart`：

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-api-domain.com/api'; // 修改为实际地址
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
```

### 2. 在 main.dart 中初始化 Riverpod

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/loading_overlay.dart';

void main() {
  runApp(
    const ProviderScope(  // 包裹 ProviderScope
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '随礼记',
      builder: (context, child) {
        return LoadingOverlay(child: child!);  // 添加全局 Loading
      },
      home: HomeScreen(),
    );
  }
}
```

### 3. 在页面中使用 API

#### 示例 1: 显示礼金列表

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_providers.dart';

class GiftsListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(giftsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text('礼金列表')),
      body: giftsAsync.when(
        data: (gifts) => ListView.builder(
          itemCount: gifts.length,
          itemBuilder: (context, index) {
            final gift = gifts[index];
            return ListTile(
              title: Text('¥${gift.amount}'),
              subtitle: Text(gift.eventType),
              trailing: Text(gift.isReceived ? '收礼' : '送礼'),
            );
          },
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('加载失败: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(giftsNotifierProvider),
                child: Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 添加礼金记录
          final gift = Gift(
            guestId: 1,
            amount: 500.0,
            isReceived: true,
            eventType: '婚礼',
            date: DateTime.now(),
          );

          await ref.read(giftsNotifierProvider.notifier).addGift(gift);
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
```

#### 示例 2: 添加礼金记录

```dart
Future<void> addGiftRecord(WidgetRef ref, Gift gift) async {
  try {
    await ref.read(giftsNotifierProvider.notifier).addGift(gift);

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('添加成功')),
    );
  } catch (e) {
    // 显示错误提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('添加失败: $e')),
    );
  }
}
```

#### 示例 3: 删除礼金记录

```dart
Future<void> deleteGiftRecord(WidgetRef ref, int giftId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('确认删除'),
      content: Text('确定要删除这条记录吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('删除'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(giftsNotifierProvider.notifier).deleteGift(giftId);
  }
}
```

#### 示例 4: 显示统计数据

```dart
class StatisticsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statisticsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text('数据统计')),
      body: statsAsync.when(
        data: (stats) => Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: ListTile(
                  title: Text('总收入'),
                  trailing: Text('¥${stats.totalReceived}'),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('总支出'),
                  trailing: Text('¥${stats.totalSent}'),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('余额'),
                  trailing: Text(
                    '¥${stats.balance}',
                    style: TextStyle(
                      color: stats.balance >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }
}
```

#### 示例 5: 下拉刷新

```dart
class GiftsListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(giftsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text('礼金列表')),
      body: giftsAsync.when(
        data: (gifts) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(giftsNotifierProvider.notifier).refresh();
          },
          child: ListView.builder(
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              final gift = gifts[index];
              return ListTile(
                title: Text('¥${gift.amount}'),
                subtitle: Text(gift.eventType),
              );
            },
          ),
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }
}
```

## 🔧 高级用法

### 1. 禁用某个请求的 Loading 状态

```dart
final response = await dio.get(
  '/gifts',
  options: Options(
    extra: {'showLoading': false},  // 不显示全局 loading
  ),
);
```

### 2. 设置 Token

```dart
// 登录成功后设置 token
ref.read(authTokenProvider.notifier).state = 'your-jwt-token';

// 登出时清除 token
ref.read(authTokenProvider.notifier).state = null;
```

### 3. 自定义错误处理

```dart
try {
  await ref.read(giftsNotifierProvider.notifier).addGift(gift);
} on ApiException catch (e) {
  if (e.code == 401) {
    // Token 过期，跳转登录
    Navigator.pushReplacementNamed(context, '/login');
  } else {
    // 显示错误信息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
```

### 4. 批量操作

```dart
// 批量添加礼金记录
final gifts = [
  Gift(guestId: 1, amount: 500, isReceived: true, eventType: '婚礼', date: DateTime.now()),
  Gift(guestId: 2, amount: 300, isReceived: true, eventType: '满月', date: DateTime.now()),
];

await ref.read(giftsNotifierProvider.notifier).batchAddGifts(gifts);
```

## 📝 API 响应格式

后端 API 应返回以下格式：

### 成功响应

```json
{
  "success": true,
  "data": {
    "id": 1,
    "guestId": 1,
    "amount": 500.0,
    "isReceived": true,
    "eventType": "婚礼",
    "date": "2026-02-07T10:00:00Z"
  },
  "message": "操作成功",
  "code": 200
}
```

### 列表响应

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "guestId": 1,
      "amount": 500.0,
      "isReceived": true,
      "eventType": "婚礼",
      "date": "2026-02-07T10:00:00Z"
    }
  ],
  "message": "查询成功",
  "code": 200
}
```

### 错误响应

```json
{
  "success": false,
  "data": null,
  "message": "礼金记录不存在",
  "code": 404
}
```

## 🧪 测试建议

### 1. 使用 Mock 数据测试

在开发阶段，可以先使用本地数据库，等后端 API 就绪后再切换。

### 2. 使用 Postman/Insomnia 测试 API

确保后端 API 返回格式符合预期。

### 3. 错误场景测试

- 网络断开
- Token 过期
- 服务器错误（500）
- 数据格式错误

## 🔐 安全注意事项

1. **不要在代码中硬编码 API 密钥**
2. **使用 HTTPS** 加密传输
3. **Token 存储在安全位置**（flutter_secure_storage）
4. **敏感数据加密**（密码、身份证等）

## 📚 相关文档

- [Dio 官方文档](https://pub.dev/packages/dio)
- [Riverpod 官方文档](https://riverpod.dev/)
- [Flutter 网络请求最佳实践](https://docs.flutter.dev/cookbook/networking)

## 🐛 常见问题

### Q: 如何调试网络请求？

A: 拦截器已经内置了日志输出，在 Debug 模式下会自动打印请求和响应。

### Q: 如何处理超时？

A: 在 `ApiConfig` 中调整 `connectTimeout` 和 `receiveTimeout`。

### Q: 如何取消请求？

A: 使用 `CancelToken`：

```dart
final cancelToken = CancelToken();

dio.get('/gifts', cancelToken: cancelToken);

// 取消请求
cancelToken.cancel('用户取消');
```

### Q: 如何上传文件？

A: 使用 `FormData`：

```dart
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(filePath),
  'name': 'receipt.jpg',
});

await dio.post('/upload', data: formData);
```
