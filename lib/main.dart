import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 移除不兼容的 imports
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
// 移除不兼容的 imports
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/add_record_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
// import 'widgets/quantum_bottom_nav_bar.dart'; // 暂时禁用自定义导航栏


// 条件导入
// 条件导入 - 仅桌面端需要初始化
import 'services/db_init_native.dart' if (dart.library.js_interop) 'services/db_init_stub.dart' as db_init;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库 (仅桌面端)
  db_init.initializeDatabase();

  // 初始化通知服务
  await NotificationService().initialize();

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const GiftMoneyTrackerApp());
}

class GiftMoneyTrackerApp extends StatelessWidget {
  const GiftMoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '随礼记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 禁用滚动发光效果，防止出现奇怪的边框
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

  // GlobalKey 用于访问子页面状态
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<StatisticsScreenState> _statisticsKey = GlobalKey();
  final GlobalKey<SettingsScreenState> _settingsKey = GlobalKey();

  List<Widget> get _screens => [
    DashboardScreen(key: _dashboardKey),
    StatisticsScreen(key: _statisticsKey),
    SettingsScreen(key: _settingsKey),
  ];

  void _refreshPage(int index) {
    if (index == 0) {
      _dashboardKey.currentState?.refreshData();
    } else if (index == 1) {
      _statisticsKey.currentState?.refreshData();
    } else if (index == 2) {
      _settingsKey.currentState?.refreshData();
    }
  }

  // 打开添加记录页面
  Future<void> _openAddRecord() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecordScreen(),
      ),
    );
    
    // 如果保存成功，刷新所有页面
    if (result == true) {
      _refreshPage(0);
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _refreshPage(index);
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
          Stack(
            children: List.generate(_screens.length, (index) {
              final isActive = _currentIndex == index;
              return IgnorePointer(
                ignoring: !isActive,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  opacity: isActive ? 1 : 0,
                  child: _screens[index],
                ),
              );
            }),
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
