import 'package:flutter/material.dart';

import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/orbit_map.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  StatisticsScreenState createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  final StorageService _db = StorageService();

  List<Gift> _allGifts = [];
  Map<int, Guest> _guestMap = {};
  String? _selectedCategory;
  List<int> _availableYears = [];
  int? _selectedYear;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final gifts = await _db.getAllGifts();
      final guests = await _db.getAllGuests();

      final years = gifts.map((gift) => gift.date.year).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final selectedYear = _selectedYear != null && years.contains(_selectedYear)
          ? _selectedYear
          : null;

      if (mounted) {
        setState(() {
          _allGifts = gifts;
          _guestMap = {for (var g in guests) g.id!: g};
          _availableYears = years;
          _selectedYear = selectedYear;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '统计分析',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '数据概览与往来详情',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary.withOpacity(0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
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
    return _yearFilteredGifts.where((g) => g.eventType == _selectedCategory).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Gift> get _yearFilteredGifts {
    if (_selectedYear == null) return _allGifts;
    return _allGifts.where((g) => g.date.year == _selectedYear).toList();
  }

  Widget _buildYearSelector() {
    if (_availableYears.isEmpty) return const SizedBox.shrink();

    // 使用固定宽度确保菜单和按钮完全对齐，且切换年份时不会跳动
    const double selectorWidth = 118.0;

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: AppTheme.primaryColor.withOpacity(0.05),
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
        shadowColor: Colors.black.withOpacity(0.05),
        // 强制菜单宽度与按钮一致
        constraints: const BoxConstraints.tightFor(width: selectorWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.1)),
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
                  color: _selectedYear == null ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '全部年份',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedYear == null ? FontWeight.w700 : FontWeight.w500,
                      color: _selectedYear == null ? AppTheme.primaryColor : AppTheme.textPrimary,
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
                    color: _selectedYear == year ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$year年',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedYear == year ? FontWeight.w700 : FontWeight.w500,
                        color: _selectedYear == year ? AppTheme.primaryColor : AppTheme.textPrimary,
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
            color: _selectedYear == null ? Colors.white : AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedYear == null 
                  ? AppTheme.textSecondary.withOpacity(0.1) 
                  : AppTheme.primaryColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 两端对齐，图标在两侧
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: _selectedYear == null ? AppTheme.textSecondary : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedYear == null ? '全部' : '$_selectedYear',
                    style: TextStyle(
                      color: _selectedYear == null ? AppTheme.textPrimary : AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _selectedYear == null 
                    ? AppTheme.textSecondary.withOpacity(0.5) 
                    : AppTheme.primaryColor.withOpacity(0.5),
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
            color: Colors.black.withOpacity(0.2),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: 32,
              color: AppTheme.primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '查看详细人情往来',
                style: TextStyle(
                  color: AppTheme.textPrimary.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '点击上方图表分类展开详情',
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
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
