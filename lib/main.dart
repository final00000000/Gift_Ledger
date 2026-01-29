import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/add_record_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/storage_service.dart';

// 条件导入 - 仅桌面端需要初始化
import 'services/db_init_native.dart' if (dart.library.js_interop) 'services/db_init_stub.dart' as db_init;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库 (仅桌面端) - 同步操作，必须在 runApp 前完成
  db_init.initializeDatabase();

  // 设置系统UI样式 - 沉浸式状态栏，与应用背景色一致
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFF2F3F5),  // AppTheme.backgroundColor
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF2F3F5),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 立即启动 UI - 直接进入主页
  runApp(const GiftMoneyTrackerApp());

  // 后台初始化非关键服务（不阻塞 UI）
  _initServicesInBackground();
}

/// 后台初始化服务，完全不阻塞 UI
void _initServicesInBackground() {
  Future.microtask(() async {
    await Future.wait([
      NotificationService().initialize(),
      SecurityService().init(),
    ]);
  });
}

class GiftMoneyTrackerApp extends StatelessWidget {
  const GiftMoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 使用 ChangeNotifierProvider.value 因为服务是单例，已经创建
        ChangeNotifierProvider.value(value: StorageService()),
        ChangeNotifierProvider.value(value: SecurityService()),
      ],
      child: MaterialApp(
        title: '随礼记',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          overscroll: false,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
        home: const MainNavigation(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<_NavItem> _navItems = [
    _NavItem(label: '首页', icon: Icons.home_rounded),
    _NavItem(label: '统计', icon: Icons.bar_chart_rounded),
    _NavItem(label: '设置', icon: Icons.settings_rounded),
  ];

  // 缓存屏幕实例，避免每次访问都创建新实例
  // 移除 GlobalKey 反模式，使用 Provider 自动刷新机制
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // 初始化屏幕列表（只创建一次）
    _screens = [
      const DashboardScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
  }

  // 打开添加记录页面
  Future<void> _openAddRecord() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecordScreen(),
      ),
    );
    // 不再需要手动刷新，StorageService 会通过 notifyListeners() 自动触发页面刷新
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    // 不再需要手动刷新，页面会自动响应数据变化
  }

  Widget _buildDynamicDock() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_navItems.length, (index) {
          return _buildTabItem(index);
        }),
      ),
    );
  }

  Widget _buildTabItem(int index) {
    final isActive = _currentIndex == index;
    final item = _navItems[index];

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          item.icon,
          color: isActive ? Colors.white : AppTheme.textSecondary,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dockBottomPadding = 12.0;
    const dockHeight = 64.0;
    const fabSpacing = 12.0;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final dockSafeBottom = bottomInset > dockBottomPadding ? bottomInset : dockBottomPadding;
    final fabBottomOffset = dockSafeBottom + dockHeight + fabSpacing;
    return Scaffold(
      // extendBody 移除，避免与子页面 Scaffold 冲突导致内容不可见
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // 使用 IndexedStack 替代手动管理的 Stack + AnimatedOpacity
          // IndexedStack 只渲染当前索引的子组件，但保持所有子组件的状态
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: EdgeInsets.only(bottom: dockBottomPadding),
              child: Center(
                child: RepaintBoundary(
                  child: _buildDynamicDock(),
                ),
              ),
            ),
          ),
          if (_currentIndex == 0)
            Positioned(
              right: AppTheme.spacingL,
              bottom: fabBottomOffset,
              child: FloatingActionButton(
                onPressed: _openAddRecord,
                backgroundColor: AppTheme.primaryColor,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({required this.label, required this.icon});
}
