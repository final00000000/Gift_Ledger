import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // GlobalKey 用于访问子页面状态
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<StatisticsScreenState> _statisticsKey = GlobalKey();
  final GlobalKey<SettingsScreenState> _settingsKey = GlobalKey();

  List<Widget> get _screens => [
    DashboardScreen(key: _dashboardKey),
    StatisticsScreen(key: _statisticsKey),
    SettingsScreen(key: _settingsKey),
  ];

  // 刷新所有页面
  void _refreshAllPages() {
    _dashboardKey.currentState?.refreshData();
    _statisticsKey.currentState?.refreshData();
    _settingsKey.currentState?.refreshData();
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
      _refreshAllPages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: _openAddRecord,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ) : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXL,
              vertical: AppTheme.spacingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: '统计',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        // 切换时刷新对应页面
        switch (index) {
          case 0:
            _dashboardKey.currentState?.refreshData();
            break;
          case 1:
            _statisticsKey.currentState?.refreshData();
            break;
          case 2:
            _settingsKey.currentState?.refreshData();
            break;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
