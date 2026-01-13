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

  double _totalReceived = 0;
  double _totalSent = 0;
  List<Gift> _allGifts = [];
  Map<int, Guest> _guestMap = {};
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final totalReceived = await _db.getTotalReceived();
      final totalSent = await _db.getTotalSent();
      final gifts = await _db.getAllGifts();
      final guests = await _db.getAllGuests();

      // 按事件类型统计
      Map<String, double> receivedByEvent = {};
      Map<String, double> sentByEvent = {};

      for (var gift in gifts) {
        if (gift.isReceived) {
          receivedByEvent[gift.eventType] =
              (receivedByEvent[gift.eventType] ?? 0) + gift.amount;
        } else {
          sentByEvent[gift.eventType] =
              (sentByEvent[gift.eventType] ?? 0) + gift.amount;
        }
      }

      if (mounted) {
        setState(() {
          _totalReceived = totalReceived;
          _totalSent = totalSent;
          _allGifts = gifts;
          _guestMap = {for (var g in guests) g.id!: g};
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
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const LoadingWidget(message: '加载统计数据...')
            : (_totalReceived == 0 && _totalSent == 0)
                ? EmptyStateWidget(data: EmptyStates.noStatistics())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppTheme.primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '统计',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                          // 分类对称柱状图
                          SymmetryBarChart(
                            gifts: _allGifts,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: (category) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingL),

                          // 选中分类的详细流水 (Orbit Map)
                          // 选中分类的详细流水 (Orbit Map)
                          if (_selectedCategory != null)
                            _buildCategoryDetailSection()
                          else
                            _buildPlaceholderHint(),

                          const SizedBox(height: 100),
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
    return _allGifts.where((g) => g.eventType == _selectedCategory).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
