import 'package:flutter/material.dart';

import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/orbit_map.dart';
import '../widgets/pin_code_dialog.dart';
import '../widgets/insight_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  StatisticsScreenState createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  final StorageService _db = StorageService();
  final SecurityService _securityService = SecurityService();

  List<Gift> _allGifts = [];
  Map<int, Guest> _guestMap = {};
  String? _selectedCategory;
  List<int> _availableYears = [];
  int? _selectedYear;
  bool _isLoading = true;

  // 智能洞察数据
  double? _receivedTrend;
  double? _mostCommonAmount;
  String? _mostFrequentContact;
  int _mostFrequentContactCount = 0;

  @override
  void initState() {
    super.initState();
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
        // 计算洞察数据
        _calculateInsights(_allGifts, _guestMap);
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

  /// 计算智能洞察数据
  void _calculateInsights(List<Gift> allGifts, Map<int, Guest> guestMap) {
    if (allGifts.isEmpty) return;

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonth.subtract(const Duration(days: 1));

    // 计算本月和上月的收礼/送礼总额
    double thisMonthReceived = 0;
    double lastMonthReceived = 0;

    // 统计金额频率和联系人频率
    final amountCount = <double, int>{};
    final contactCount = <int, int>{};

    for (final gift in allGifts) {
      // 本月数据
      if (gift.date.isAfter(thisMonth.subtract(const Duration(seconds: 1)))) {
        if (gift.isReceived) {
          thisMonthReceived += gift.amount;
        }
      }
      // 上月数据
      else if (gift.date.isAfter(lastMonth.subtract(const Duration(seconds: 1))) &&
          gift.date.isBefore(lastMonthEnd.add(const Duration(days: 1)))) {
        if (gift.isReceived) {
          lastMonthReceived += gift.amount;
        }
      }

      // 统计金额频率
      amountCount[gift.amount] = (amountCount[gift.amount] ?? 0) + 1;

      // 统计联系人频率
      if (gift.guestId != null) {
        contactCount[gift.guestId!] = (contactCount[gift.guestId!] ?? 0) + 1;
      }
    }

    // 计算环比变化
    if (lastMonthReceived > 0) {
      _receivedTrend = ((thisMonthReceived - lastMonthReceived) / lastMonthReceived) * 100;
    } else if (thisMonthReceived > 0) {
      _receivedTrend = 100;
    } else {
      _receivedTrend = null;
    }

    // 找出最常见金额
    if (amountCount.isNotEmpty) {
      var maxCount = 0;
      double? mostCommon;
      amountCount.forEach((amount, count) {
        if (count > maxCount) {
          maxCount = count;
          mostCommon = amount;
        }
      });
      _mostCommonAmount = mostCommon;
    }

    // 找出最频繁联系人
    if (contactCount.isNotEmpty) {
      var maxCount = 0;
      int? mostFrequentId;
      contactCount.forEach((guestId, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequentId = guestId;
        }
      });
      if (mostFrequentId != null && guestMap.containsKey(mostFrequentId)) {
        _mostFrequentContact = guestMap[mostFrequentId]!.name;
        _mostFrequentContactCount = maxCount;
      }
    }
  }

  /// 构建智能洞察数据
  List<InsightData> _buildInsights() {
    final insights = <InsightData>[];

    // 环比变化洞察
    if (_receivedTrend != null) {
      final trend = _receivedTrend!;
      final isUp = trend >= 0;
      insights.add(InsightData(
        title: '本月收礼趋势',
        value: '${isUp ? "增长" : "下降"} ${trend.abs().toStringAsFixed(1)}%',
        description: '相比上月',
        icon: isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      ));
    }

    // 最常见金额洞察
    if (_mostCommonAmount != null) {
      insights.add(InsightData(
        title: '最常见礼金金额',
        value: '¥${_mostCommonAmount!.toStringAsFixed(0)}',
        description: '出现频率最高',
        icon: Icons.attach_money_rounded,
      ));
    }

    // 最频繁联系人洞察
    if (_mostFrequentContact != null) {
      insights.add(InsightData(
        title: '最常往来联系人',
        value: _mostFrequentContact!,
        description: '共 $_mostFrequentContactCount 次往来',
        icon: Icons.person_rounded,
      ));
    }

    // 如果没有足够数据，添加默认洞察
    if (insights.isEmpty) {
      insights.add(const InsightData(
        title: '开始记录',
        value: '添加更多记录解锁洞察',
        description: '智能分析您的礼金往来',
        icon: Icons.auto_awesome,
      ));
    }

    return insights;
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
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                                      ? AppTheme.primaryColor.withOpacity(0.08)
                                      : Colors.grey.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () async {
                                    if (isUnlocked) {
                                      _securityService.lock();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('金额已隐藏'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    } else {
                                      await PinCodeDialog.show(context);
                                    }
                                  },
                                  icon: Icon(
                                    isUnlocked
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 20,
                                    color: isUnlocked ? AppTheme.primaryColor : AppTheme.textSecondary,
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
                            insights: _buildInsights(),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              color: AppTheme.primaryColor.withOpacity(0.08),
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
