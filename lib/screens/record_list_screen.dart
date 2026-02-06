import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import 'add_record_screen.dart';
import '../services/security_service.dart';
import '../utils/security_unlock.dart';
import '../widgets/privacy_aware_text.dart';

class RecordListScreen extends StatefulWidget {
  final bool? isReceived; // null = 显示全部记录

  const RecordListScreen({
    super.key,
    this.isReceived, // 改为可?
  });

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _db = StorageService();
  final SecurityService _securityService = SecurityService();
  final TextEditingController _searchController = TextEditingController();

  // 搜索防抖定时器
  Timer? _debounceTimer;

  /// 验证安全锁，返回是否通过验证（统一入口）
  Future<bool> _verifySecurityLock() => _securityService.ensureUnlocked(context);

  List<Gift> _allGifts = [];
  List<Gift> _filteredGifts = [];
  Map<int, Guest> _guestMap = {};
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

      if (mounted) {
        setState(() {
          // 如果 isReceived ?null，显示全部记?
          _allGifts = widget.isReceived == null
              ? gifts
              : gifts.where((g) => g.isReceived == widget.isReceived).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          _guestMap = {for (var g in guests) g.id!: g};
          _filterGifts();
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
    // 取消之前的定时器
    _debounceTimer?.cancel();

    // 设置新的防抖定时器（300ms）
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
          _filterGifts();
        });
      }
    });
  }

  // 新增变量存储统计信息
  double _filteredTotalAmount = 0;
  int _filteredCount = 0;

  void _filterGifts() {
    final filtered = _allGifts.where((gift) {
      // 分类筛选
      if (_selectedCategory != 'all' && gift.eventType != _selectedCategory) {
        return false;
      }

      // 搜索筛选（需要通过 guestMap 获取名字）
      if (_searchQuery.isNotEmpty) {
        final guest = _guestMap[gift.guestId];
        final nameMatch = guest?.name.toLowerCase().contains(_searchQuery) ?? false;
        final noteMatch = gift.note?.toLowerCase().contains(_searchQuery) ?? false;
        return nameMatch || noteMatch;
      }

      return true;
    }).toList();

    // 计算统计数据（使用 fold 简化）
    final total = filtered.fold<double>(0, (sum, gift) => sum + gift.amount);

    setState(() {
      _filteredGifts = filtered;
      _filteredTotalAmount = total;
      _filteredCount = filtered.length;
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
        padding: const EdgeInsets.fromLTRB(AppTheme.spacingL, AppTheme.spacingM, AppTheme.spacingL, 0),
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
              style: TextStyle(
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
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
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
        child: ListView.separated( // 使用 separated 自动处理间距
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
                  _filterGifts();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? activeColor : AppTheme.textSecondary.withValues(alpha: 0.2),
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

    // 构建分组列表项
    final List<Widget> listItems = [];
    String? currentMonth;

    for (int i = 0; i < _filteredGifts.length; i++) {
      final gift = _filteredGifts[i];
      final monthStr = DateFormat('yyyy年MM月').format(gift.date);

      // 如果月份变化，插入标题
      if (currentMonth != monthStr) {
        currentMonth = monthStr;
        listItems.add(
          Padding(
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
                        color: _getAccentColor().withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        monthStr,
                        style: TextStyle(
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
                          _getAccentColor().withValues(alpha: 0.2),
                          _getAccentColor().withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final guest = _guestMap[gift.guestId]; // 修复：这里应该是 guestId 而不是 id
      
      // 构建动画
      final animation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            (i * 0.05).clamp(0.0, 1.0),
            ((i * 0.05) + 0.3).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );

      listItems.add(
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - animation.value)),
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
          child: _buildGiftItem(gift, guest),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL, vertical: AppTheme.spacingS),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => listItems[index],
          childCount: listItems.length,
        ),
      ),
    );
  }

  Widget _buildGiftItem(Gift gift, Guest? guest) {
    final guestName = guest?.name ?? '未知联系人';
    final itemColor = gift.isReceived ? AppTheme.primaryColor : AppTheme.accentColor;
    final solarDate = DateFormat('MM-dd').format(gift.date); // 缩短日期显示，因为月份已经在标题了
    final lunarDate = LunarUtils.getLunarDateString(gift.date);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (!await _verifySecurityLock()) return;
            _showGiftDetail(gift, guest);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 左侧图标：更具设计感的容器
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        itemColor.withValues(alpha: 0.12),
                        itemColor.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    gift.isReceived ? Icons.move_to_inbox_rounded : Icons.outbox_rounded,
                    color: itemColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // 中间信息：清晰的层级
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightedText(
                        guestName,
                        const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              gift.eventType,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: itemColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            solarDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (lunarDate.isNotEmpty) ...[
                            Text(
                              ' · $lunarDate',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 右侧金额：醒目加粗
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PrivacyAwareText(
                      '${gift.isReceived ? "+" : "-"}¥${gift.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: itemColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (gift.note != null && gift.note!.isNotEmpty)
                      const Icon(
                        Icons.notes_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGiftDetail(Gift gift, Guest? guest) {
    final guestName = guest?.name ?? '未知联系人';
    final itemColor = gift.isReceived ? AppTheme.primaryColor : AppTheme.accentColor;

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
                          builder: (context) => AddRecordScreen(editingGift: gift, editingGuest: guest),
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
        content: Text('确定要删除这条记录吗？\n\n$guestName · ${gift.eventType}\n¥${gift.amount.toStringAsFixed(0)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await _db.deleteGift(gift.id!);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, TextStyle baseStyle) {
    if (_searchQuery.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    int currentIndex = 0;

    while (currentIndex < text.length) {
      final matchIndex = lowerText.indexOf(_searchQuery, currentIndex);

      if (matchIndex == -1) {
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: baseStyle,
        ));
        break;
      }

      if (matchIndex > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, matchIndex),
          style: baseStyle,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + _searchQuery.length),
        style: baseStyle.copyWith(
          backgroundColor: _getAccentColor().withValues(alpha: 0.2),
          fontWeight: FontWeight.w900,
        ),
      ));

      currentIndex = matchIndex + _searchQuery.length;
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
