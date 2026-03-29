import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../services/record_list_computation_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import 'add_record_screen.dart';
import '../services/security_service.dart';
import '../utils/security_unlock.dart';
import '../widgets/privacy_aware_text.dart';
import '../widgets/records/record_summary_card.dart';

abstract class RecordListStorage {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Future<List<Gift>> getAllGifts();
  Future<List<Guest>> getAllGuests();
  Future<int> deleteGift(int id);
}

class _RecordListStorageAdapter implements RecordListStorage {
  _RecordListStorageAdapter(this._storageService);

  final StorageService _storageService;

  @override
  void addListener(VoidCallback listener) => _storageService.addListener(listener);

  @override
  Future<int> deleteGift(int id) => _storageService.deleteGift(id);

  @override
  Future<List<Gift>> getAllGifts() => _storageService.getAllGifts();

  @override
  Future<List<Guest>> getAllGuests() => _storageService.getAllGuests();

  @override
  void removeListener(VoidCallback listener) =>
      _storageService.removeListener(listener);
}

class RecordListScreen extends StatefulWidget {
  final bool? isReceived; // null = 显示全部记录
  final RecordListStorage? storageService;

  const RecordListScreen({
    super.key,
    this.isReceived,
    this.storageService,
  });

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _listAnimationDuration = Duration(milliseconds: 360);
  static const double _listItemInterval = 0.035;
  static const double _listItemWindow = 0.22;

  late final RecordListStorage _db;
  final SecurityService _securityService = SecurityService();
  final RecordListComputationService _recordListComputationService =
      const RecordListComputationService();
  final TextEditingController _searchController = TextEditingController();

  // 搜索防抖定时器
  Timer? _debounceTimer;

  /// 验证安全锁，返回是否通过验证（统一入口）
  Future<bool> _verifySecurityLock() =>
      _securityService.ensureUnlocked(context);

  List<Gift> _allGifts = [];
  List<Gift> _filteredGifts = [];
  Map<int, Guest> _guestMap = {};
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  double _filteredTotalAmount = 0;
  int _filteredCount = 0;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _db = widget.storageService ?? _RecordListStorageAdapter(StorageService());
    _animationController = AnimationController(
      vsync: this,
      duration: _listAnimationDuration,
    );
    // 监听 StorageService 变化，自动刷新数据
    _db.addListener(_onDataChanged);
    _loadData();
    _searchController.addListener(_onSearchChanged);
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
    _animationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel(); // 取消防抖定时器
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final gifts = await _db.getAllGifts();
      final guests = await _db.getAllGuests();
      final snapshot = _recordListComputationService.buildSnapshot(
        gifts: gifts,
        guests: guests,
        isReceived: widget.isReceived,
        selectedCategory: _selectedCategory,
        searchQuery: _searchQuery,
      );

      if (mounted) {
        setState(() {
          _allGifts = snapshot.allGifts;
          _filteredGifts = snapshot.filteredGifts;
          _guestMap = snapshot.guestMap;
          _filteredTotalAmount = snapshot.filteredTotalAmount;
          _filteredCount = snapshot.filteredCount;
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
        _recomputeFilteredState();
      }
    });
  }

  void _recomputeFilteredState() {
    final snapshot = _recordListComputationService.buildSnapshot(
      gifts: _allGifts,
      guests: _guestMap.values.toList(growable: false),
      isReceived: null,
      selectedCategory: _selectedCategory,
      searchQuery: _searchQuery,
    );

    setState(() {
      _filteredGifts = snapshot.filteredGifts;
      _filteredTotalAmount = snapshot.filteredTotalAmount;
      _filteredCount = snapshot.filteredCount;
    });
  }

  /// 获取主题色，null 时使用默认主题
  Color _getAccentColor() {
    if (widget.isReceived == null) return AppTheme.primaryColor;
    return widget.isReceived! ? AppTheme.primaryColor : AppTheme.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildSummaryHeader(), // 新增统计头
          _buildSearchBar(),
          _buildCategoryFilter(),
          _buildRecordList(),
        ],
      ),
    );
  }

  // 新增统计头部 Widget
  Widget _buildSummaryHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingL, AppTheme.spacingM, AppTheme.spacingL, 0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getAccentColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_filteredCount 笔记录',
                style: TextStyle(
                  color: _getAccentColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '总计 ',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            PrivacyAwareText(
              '¥${_filteredTotalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    // 根据 isReceived 状态决定标题和颜色
    final String title;
    final Color barColor;
    if (widget.isReceived == null) {
      title = '全部记录';
      barColor = AppTheme.textPrimary;
    } else if (widget.isReceived!) {
      title = '收礼记录';
      barColor = AppTheme.primaryColor;
    } else {
      title = '送礼记录';
      barColor = AppTheme.accentColor;
    }

    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: barColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索姓名',
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    // 使用统一的事由类型定义
    final categories = [
      {'id': 'all', 'label': '全部'},
      ...EventTypes.all.map((type) => {'id': type, 'label': type}),
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 40, // 稍微减小高度
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        child: ListView.separated(
          // 使用 separated 自动处理间距
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category['id'];
            final activeColor = _getAccentColor();

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category['id']!;
                });
                _recomputeFilteredState();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? activeColor
                        : AppTheme.textSecondary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  category['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredGifts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? '未找到匹配记录' : '暂无记录',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accentColor = _getAccentColor();
    final monthHeaders = <int, String>{};
    String? currentMonth;
    for (int i = 0; i < _filteredGifts.length; i++) {
      final monthStr = DateFormat('yyyy年MM月').format(_filteredGifts[i].date);
      if (currentMonth != monthStr) {
        currentMonth = monthStr;
        monthHeaders[i] = monthStr;
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingS,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final gift = _filteredGifts[index];
            final guest = _guestMap[gift.guestId];
            final animation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                (index * _listItemInterval).clamp(0.0, 1.0),
                math.min(1.0, (index * _listItemInterval) + _listItemWindow),
                curve: Curves.easeOut,
              ),
            );

            return Column(
              children: [
                if (monthHeaders.containsKey(index))
                  _buildMonthHeader(monthHeaders[index]!, accentColor),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 16 * (1 - animation.value)),
                      child: Opacity(
                        opacity: animation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildGiftItem(gift, guest),
                ),
              ],
            );
          },
          childCount: _filteredGifts.length,
        ),
      ),
    );
  }

  Widget _buildMonthHeader(String monthStr, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: accentColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  monthStr,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.2),
                    accentColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem(Gift gift, Guest? guest) {
    final itemColor =
        gift.isReceived ? AppTheme.primaryColor : AppTheme.accentColor;
    final solarDate = DateFormat('MM-dd').format(gift.date);
    final lunarDate = LunarUtils.getLunarDateString(gift.date);

    return RecordSummaryCard(
      gift: gift,
      guest: guest,
      solarDate: solarDate,
      lunarDate: lunarDate,
      itemColor: itemColor,
      onTap: () async {
        if (!await _verifySecurityLock()) return;
        _showGiftDetail(gift, guest);
      },
    );
  }

  void _showGiftDetail(Gift gift, Guest? guest) {
    final guestName = guest?.name ?? '未知联系人';
    final itemColor =
        gift.isReceived ? AppTheme.primaryColor : AppTheme.accentColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动条
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    gift.isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                    color: itemColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guestName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        guest?.relationship ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            // 详情信息
            _buildDetailRow('类型', gift.isReceived ? '收礼' : '送礼'),
            _buildDetailRow('事由', gift.eventType),
            _buildDetailRow('金额', '¥${gift.amount.toStringAsFixed(0)}'),
            _buildDetailRow('日期', DateFormat('yyyy年MM月dd日').format(gift.date)),
            _buildDetailRow('农历', LunarUtils.getFullLunarString(gift.date)),
            if (gift.note != null && gift.note!.isNotEmpty)
              _buildDetailRow('备注', gift.note!),
            const SizedBox(height: 24),
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddRecordScreen(
                              editingGift: gift, editingGuest: guest),
                        ),
                      );
                      if (result == true) {
                        _loadData();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(gift, guestName);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Gift gift, String guestName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除这条记录吗？\n\n$guestName · ${gift.eventType}\n¥${gift.amount.toStringAsFixed(0)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              await _db.deleteGift(gift.id!);
              if (!mounted) return;

              navigator.pop();
              _loadData();
              messenger.showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}


