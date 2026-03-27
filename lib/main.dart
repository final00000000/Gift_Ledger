import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // 启动页优化
import 'package:provider/provider.dart';

import 'models/update_target.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'services/config_service.dart';
import 'services/db_init_native.dart'
    if (dart.library.js_interop) 'services/db_init_stub.dart' as db_init;
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/storage_service.dart';
import 'services/update/app_build_info_service.dart';
import 'services/update/update_controller.dart';
import 'services/update/update_prompt_policy.dart';
import 'services/update/update_repository.dart';
import 'services/update/update_ui_coordinator.dart';
import 'theme/app_theme.dart';
import 'widgets/update/update_prompt_dialog.dart';

void main() async {
  // 1. 提前初始化 Flutter 绑定
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 2. 🔑 保留原生启动页，避免过早消失导致黑屏
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 预加载配置服务（一次性加载所有 SharedPreferences 到内存）
  await ConfigService().init();

  // 设置系统UI样式 - 沉浸式状态栏，与应用背景色一致
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFFAF8F5),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFFAF8F5),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 3. 🔑 优先启动 UI - 确保 Flutter 首帧尽快渲染
  runApp(const GiftMoneyTrackerApp());

  // 4. 🔑 首帧渲染完成后，立即移除启动页（无缝切换）
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });

  // 5. 后台初始化非关键服务（不阻塞 UI）
  _initServicesInBackground();
}

/// 后台初始化服务，完全不阻塞 UI
void _initServicesInBackground() {
  Future.microtask(() async {
    // 并行初始化所有后台服务
    await Future.wait([
      // 数据库初始化（移到后台，不阻塞 UI 启动）
      Future(() => db_init.initializeDatabase()),
      NotificationService().initialize(),
      SecurityService().init(),
    ]);

    // 数据库初始化完成后，预热常用数据
    await StorageService().warmup();
  });
}

class GiftMoneyTrackerApp extends StatelessWidget {
  const GiftMoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 使用 ChangeNotifierProvider 延迟创建，避免启动时立即实例化
        ChangeNotifierProvider(create: (_) => StorageService()),
        ChangeNotifierProvider(create: (_) => SecurityService()),
        ChangeNotifierProvider(
          create: (_) => UpdateController(
            repository: UpdateRepository(),
            appBuildInfoService: const AppBuildInfoService(),
          ),
        ),
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
  const MainNavigation({
    super.key,
    this.screens,
    this.promptPresenter = _defaultUpdatePromptPresenter,
  });

  final List<Widget>? screens;
  final UpdatePromptPresenter promptPresenter;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

typedef UpdatePromptPresenter = Future<UpdatePromptDialogResult?> Function(
  BuildContext context,
  UpdateTarget target,
  VoidCallback onShown,
);

Future<UpdatePromptDialogResult?> _defaultUpdatePromptPresenter(
  BuildContext context,
  UpdateTarget target,
  VoidCallback onShown,
) {
  return showDialog<UpdatePromptDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdatePromptDialog(
      target: target,
      onShown: onShown,
    ),
  );
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  UpdateController? _updateController;
  bool _didScheduleStartupUpdateCheck = false;
  final UpdatePromptCoordinator _updatePromptCoordinator =
      UpdatePromptCoordinator();
  final List<_NavItem> _navItems = [
    const _NavItem(label: '首页', icon: Icons.home_rounded),
    const _NavItem(label: '统计', icon: Icons.bar_chart_rounded),
    const _NavItem(label: '设置', icon: Icons.settings_rounded),
  ];

  // 缓存屏幕实例，避免每次访问都创建新实例
  // 移除 GlobalKey 反模式，使用 Provider 自动刷新机制
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 初始化屏幕列表（只创建一次）
    _screens = widget.screens ??
        [
          const DashboardScreen(),
          const StatisticsScreen(),
          const SettingsScreen(),
        ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_updateController == null) {
      _updateController = context.read<UpdateController>();
      _updateController!.addListener(_handleUpdateControllerChanged);
    }

    if (!_didScheduleStartupUpdateCheck) {
      _didScheduleStartupUpdateCheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateController?.checkForUpdates(source: UpdateCheckSource.startup);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateController?.removeListener(_handleUpdateControllerChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final controller = _updateController;
    if (controller == null) {
      return;
    }

    unawaited(controller.handleAppResumed());
  }

  void _handleUpdateControllerChanged() {
    final controller = _updateController;
    if (!mounted || controller == null) {
      return;
    }

    final state = controller.state;
    final target = state.target;
    final dialogKey = _updatePromptCoordinator.beginPresentation(state);
    if (dialogKey == null || target == null) {
      return;
    }

    _presentUpdatePrompt(target: target);
  }

  Future<void> _presentUpdatePrompt({
    required UpdateTarget target,
  }) async {
    final controller = _updateController;
    if (controller == null) {
      return;
    }

    try {
      final result = await widget.promptPresenter(
        context,
        target,
        () {
          controller.markCurrentTargetPresented();
        },
      );

      if (!mounted) {
        return;
      }

      if (result?.ignoreCurrentVersion == true) {
        await controller.ignoreCurrentTarget();
      }
    } finally {
      _updatePromptCoordinator.endPresentation();
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    // 不再需要手动刷新，页面会自动响应数据变化
  }

  Widget _buildDynamicDock({
    required bool showSettingsRedDot,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_navItems.length, (index) {
          return _buildTabItem(
            index,
            showSettingsRedDot: showSettingsRedDot,
          );
        }),
      ),
    );
  }

  Widget _buildTabItem(
    int index, {
    required bool showSettingsRedDot,
  }) {
    final isActive = _currentIndex == index;
    final item = _navItems[index];
    final shouldShowBadge = index == 2 && showSettingsRedDot;

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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              item.icon,
              color: isActive ? Colors.white : AppTheme.textSecondary,
              size: 24,
            ),
            if (shouldShowBadge)
              Positioned(
                right: -1,
                top: -2,
                child: Container(
                  key: const ValueKey('settings-tab-red-dot'),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? AppTheme.textPrimary
                          : Colors.white.withValues(alpha: 0.96),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dockBottomPadding = 12.0;
    final showSettingsRedDot = context.select<UpdateController, bool>(
      (controller) => controller.state.showRedDot,
    );

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
              minimum: const EdgeInsets.only(bottom: dockBottomPadding),
              child: Center(
                child: RepaintBoundary(
                  child: _buildDynamicDock(
                    showSettingsRedDot: showSettingsRedDot,
                  ),
                ),
              ),
            ),
          ),
          // 旧的 FAB 已隐藏，使用 dashboard_screen 中的 ExpandableFab
          // if (_currentIndex == 0)
          //   Positioned(
          //     right: AppTheme.spacingL,
          //     bottom: fabBottomOffset,
          //     child: FloatingActionButton(
          //       onPressed: _openAddRecord,
          //       backgroundColor: AppTheme.primaryColor,
          //       elevation: 4,
          //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          //       child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
          //     ),
          //   ),
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
