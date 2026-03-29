import 'package:flutter/material.dart';

import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../services/security_service.dart';
import '../services/statistics_computation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/orbit_map.dart';
import '../utils/security_unlock.dart';
import '../widgets/insight_card.dart';

abstract class StatisticsStorage {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Future<List<Gift>> getAllGifts();
  Future<List<Guest>> getAllGuests();
}

class _StatisticsStorageAdapter implements StatisticsStorage {
  _StatisticsStorageAdapter(this._storageService);

  final StorageService _storageService;

  @override
  void addListener(VoidCallback listener) =>
      _storageService.addListener(listener);

  @override
  Future<List<Gift>> getAllGifts() => _storageService.getAllGifts();

  @override
  Future<List<Guest>> getAllGuests() => _storageService.getAllGuests();

  @override
  void removeListener(VoidCallback listener) =>
      _storageService.removeListener(listener);
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.storageService,
  });

  final StatisticsStorage? storageService;

  @override
  StatisticsScreenState createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  late final StatisticsStorage _db;
  final SecurityService _securityService = SecurityService();
  final StatisticsComputationService _statisticsComputationService =
      const StatisticsComputationService();

  List<Gift> _allGifts = [];
  Map<int, Guest> _guestMap = {};
  String? _selectedCategory;
  List<int> _availableYears = [];
  int? _selectedYear;
  bool _isLoading = true;
  int _dataVersion = 0;

  // 缓存年份筛选结果，避免重复计算
  List<Gift>? _cachedYearFilteredGifts;
  int? _cachedYear;
  int? _cachedDataVersion;

  // 智能洞察数据
  List<InsightData> _insights = const [];

  @override
  void initState() {
    super.initState();
    _db = widget.storageService ?? _StatisticsStorageAdapter(StorageService());
    // 监听 StorageService 变化，自动刷新数据
    _db.addListener(_onDataChanged);
    _loadData();
  }

  /// StorageService 数据变化时的回调
  void _onDataChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _db.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final gifts = await _db.getAllGifts();
      final guests = await _db.getAllGuests();
      final snapshot = _statisticsComputationService.buildSnapshot(
        gifts: gifts,
        guests: guests,
        selectedYear: _selectedYear,
      );

      if (mounted) {
        setState(() {
          _allGifts = snapshot.allGifts;
          _guestMap = snapshot.guestMap;
          _availableYears = snapshot.availableYears;
          _selectedYear = snapshot.selectedYear;
          _cachedYearFilteredGifts = snapshot.yearFilteredGifts;
          _cachedYear = snapshot.selectedYear;
          _cachedDataVersion = _dataVersion;
          _insights = snapshot.insights
              .map((insight) => InsightData(
                    title: insight.title,
                    value: insight.value,
                    description: insight.description,
                    icon: insight.icon,
                  ))
              .toList(growable: false);
          _isLoading = false;
          _dataVersion += 1;
        });
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 公开的刷新方法
  void refreshData() {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final visibleGifts = _yearFilteredGifts;
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const LoadingWidget(message: '加载统计数据...')
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 简化的头部
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '统计分析',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '数据概览与往来详情',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 安全锁按钮
                          ValueListenableBuilder<bool>(
                            valueListenable: _securityService.isUnlocked,
                            builder: (context, isUnlocked, child) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isUnlocked
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.08)
                                      : Colors.grey.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () async {
                                    if (isUnlocked) {
                                      _securityService.lock();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('金额已隐藏'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    } else {
                                      await _securityService
                                          .ensureUnlocked(context);
                                    }
                                  },
                                  icon: Icon(
                                    isUnlocked
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 20,
                                    color: isUnlocked
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildYearSelector(),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      if (visibleGifts.isEmpty)
                        EmptyStateWidget(
                          data: EmptyStates.noStatistics(),
                          animate: false,
                        )
                      else ...[
                        // 智能洞察卡片 - 数据足够时才显示
                        if (_allGifts.length >= 3) ...[
                          InsightCard(
                            insights: _insights,
                            animationDelay: const Duration(milliseconds: 200),
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                        ],
                        // 分类对称柱状图
                        SymmetryBarChart(
                          gifts: visibleGifts,
                          selectedCategory: _selectedCategory,
                          onCategorySelected: (category) {
                            setState(() => _selectedCategory = category);
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        // 选中分类的详细流水 (Orbit Map)
                        if (_selectedCategory != null)
                          _buildCategoryDetailSection()
                        else
                          _buildPlaceholderHint(),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 获取选中分类的记录
  List<Gift> get _filteredGifts {
    if (_selectedCategory == null) return [];
    return _yearFilteredGifts
        .where((g) => g.eventType == _selectedCategory)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Gift> get _yearFilteredGifts {
    if (_cachedYear == _selectedYear &&
        _cachedYearFilteredGifts != null &&
        _cachedDataVersion == _dataVersion) {
      return _cachedYearFilteredGifts!;
    }

    final filtered = _selectedYear == null
        ? _allGifts
        : _allGifts.where((g) => g.date.year == _selectedYear).toList();

    _cachedYear = _selectedYear;
    _cachedYearFilteredGifts = filtered;
    _cachedDataVersion = _dataVersion;

    return filtered;
  }

  Widget _buildYearSelector() {
    if (_availableYears.isEmpty) return const SizedBox.shrink();

    // 使用固定宽度确保菜单和按钮完全对齐，且切换年份时不会跳动
    const double selectorWidth = 118.0;

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<int>(
        initialValue: _selectedYear ?? -1,
        // 使用 -1 作为"全部年份"的哨兵值，确保回调一定会被触发
        onSelected: (int value) {
          setState(() {
            _selectedYear = value == -1 ? null : value;
            _selectedCategory = null;
          });
        },
        tooltip: '选择年份',
        offset: const Offset(0, 48),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        // 强制菜单宽度与按钮一致
        constraints: const BoxConstraints.tightFor(width: selectorWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
        ),
        itemBuilder: (context) => [
          PopupMenuItem<int>(
            value: -1,
            height: 44,
            child: Row(
              children: [
                Icon(
                  Icons.all_inclusive_rounded,
                  size: 16,
                  color: _selectedYear == null
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '全部年份',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedYear == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _selectedYear == null
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ..._availableYears.map(
            (year) => PopupMenuItem<int>(
              value: year,
              height: 44,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: _selectedYear == year
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$year年',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedYear == year
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedYear == year
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: selectorWidth, // 固定按钮宽度
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _selectedYear == null
                ? Colors.white
                : AppTheme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedYear == null
                  ? AppTheme.textSecondary.withValues(alpha: 0.1)
                  : AppTheme.primaryColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: _selectedYear == null
                          ? AppTheme.textSecondary
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _selectedYear == null ? '全部' : '$_selectedYear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _selectedYear == null
                              ? AppTheme.textPrimary
                              : AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _selectedYear == null
                    ? AppTheme.textSecondary.withValues(alpha: 0.5)
                    : AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建选中分类的详情区域 (使用 OrbitMap)
  Widget _buildCategoryDetailSection() {
    final gifts = _filteredGifts;
    if (gifts.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacingM),
      padding: const EdgeInsets.all(20), // 添加内边距防止溢出
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate 900
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: OrbitMap(
        category: _selectedCategory!,
        gifts: gifts,
        guestMap: _guestMap,
        onClose: () {
          setState(() {
            _selectedCategory = null;
          });
        },
      ),
    );
  }

  Widget _buildPlaceholderHint() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppTheme.spacingM),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: 24,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '查看详细人情往来',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '点击上方图表分类展开详情',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
