import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_logo.dart';
import '../widgets/hero_section.dart';
import '../widgets/horizontal_quick_actions.dart';
import '../widgets/grouped_timeline.dart';
import '../services/security_service.dart';
import '../utils/security_unlock.dart';
import 'add_record_screen.dart';
import 'record_list_screen.dart';
import 'pending_list_screen.dart';
import 'event_book_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _db = StorageService();
  double _totalReceived = 0;
  double _totalSent = 0;
  List<Gift> _recentGifts = [];
  Map<int, Guest> _guestMap = {};
  bool _isLoading = true;
  int _pendingCount = 0;
  bool _eventBooksEnabled = true;
  final SecurityService _securityService = SecurityService();
  bool _isFirstLoad = true;  // 标记是否首次加载，用于控制入场动画

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _heroAnimation;
  late Animation<double> _gridAnimation;
  late Animation<double> _listAnimation;

  /// 验证安全锁，返回是否通过验证（统一入口，避免各页面重复实现）
  Future<bool> _verifySecurityLock() => _securityService.ensureUnlocked(context);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _db.addListener(_onDataChanged);
    _loadData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // 从 1400ms 优化到 800ms
    );

    // 分层动画 - 头部 → 英雄区 → 洞察卡片 → 网格 → 列表
    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
      ),
    );

    _heroAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    _gridAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _listAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _onDataChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _db.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final includeEventBooks = await _db.getStatsIncludeEventBooks();
      final eventBooksEnabled = await _db.getEventBooksEnabled();

      final results = await Future.wait([
        _db.getTotalReceived(includeEventBooks: includeEventBooks),
        _db.getTotalSent(includeEventBooks: includeEventBooks),
        _db.getRecentGifts(limit: 20),
        _db.getAllGuests(),
        _db.getPendingCount(includeEventBooks: includeEventBooks),
      ]);

      if (mounted) {
        final guests = results[3] as List<Guest>;
        final guestMap = {for (var g in guests) g.id!: g};

        setState(() {
          _totalReceived = results[0] as double;
          _totalSent = results[1] as double;
          _recentGifts = (results[2] as List<Gift>).take(10).toList();
          _guestMap = guestMap;
          _pendingCount = results[4] as int;
          _eventBooksEnabled = eventBooksEnabled;
          _isLoading = false;
        });

        // 只在首次加载时播放入场动画
        if (_isFirstLoad) {
          _isFirstLoad = false;
          _animationController.forward(from: 0.0);
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      final eventBooksEnabled = await _db.getEventBooksEnabled();
      if (mounted) {
        setState(() {
          _eventBooksEnabled = eventBooksEnabled;
          _isLoading = false;
        });
        // 只在首次加载时播放入场动画
        if (_isFirstLoad) {
          _isFirstLoad = false;
          _animationController.forward(from: 0.0);
        }
      }
    }
  }

  void refreshData() {
    _loadData();
  }

  void _navigateToRecordList(bool isReceived) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RecordListScreen(isReceived: isReceived),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) => refreshData());
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
            _buildDetailRow('类型', gift.isReceived ? '收礼' : '送礼'),
            _buildDetailRow('事由', gift.eventType),
            _buildDetailRow('金额', '¥${gift.amount.toStringAsFixed(0)}'),
            _buildDetailRow('日期', DateFormat('yyyy年MM月dd日').format(gift.date)),
            _buildDetailRow('农历', LunarUtils.getFullLunarString(gift.date)),
            if (gift.note != null && gift.note!.isNotEmpty)
              _buildDetailRow('备注', gift.note!),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!await _verifySecurityLock()) return;
                      if (!mounted) return;

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
                    onPressed: () async {
                      if (!await _verifySecurityLock()) return;
                      if (!mounted) return;

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

  Future<void> _confirmDelete(Gift gift, String guestName) async {
    if (!await _verifySecurityLock()) return;
    if (!mounted) return;

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

  /// 构建横向快捷操作项列表
  List<HorizontalActionItem> _buildHorizontalActions() {
    final items = <HorizontalActionItem>[];

    // 活动簿（如果启用）
    if (_eventBooksEnabled) {
      items.add(HorizontalActionItem(
        title: '活动簿',
        icon: Icons.book_rounded,
        color: AppTheme.eventBookColor,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EventBookListScreen(),
            ),
          ).then((_) => refreshData());
        },
      ));
    }

    // 待处理
    items.add(HorizontalActionItem(
      title: '待处理',
      icon: Icons.pending_actions_rounded,
      color: AppTheme.pendingColor,
      badge: _pendingCount > 0 ? _pendingCount : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PendingListScreen(),
          ),
        ).then((_) => refreshData());
      },
    ));

    // 全部记录
    items.add(HorizontalActionItem(
      title: '记录',
      icon: Icons.list_alt_rounded,
      color: const Color(0xFF06B6D4),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RecordListScreen(),
          ),
        ).then((_) => refreshData());
      },
    ));

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final fabBottom = 64.0 + (bottomPadding > 12 ? bottomPadding : 12.0) + 16.0; // dock高度 + 安全区域 + 间距

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                slivers: [
                  if (_isLoading && _recentGifts.isEmpty)
                    const SliverFillRemaining(
                      child: DashboardSkeleton(),
                    )
                  else ...[
                // 头部标题 - 带动画
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _headerAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _headerAnimation.value)),
                        child: Opacity(
                          opacity: _headerAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildHeader(),
                  ),
                ),

                // Hero Section - 带动画
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _heroAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - _heroAnimation.value)),
                        child: Opacity(
                          opacity: _heroAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: HeroSection(
                      totalReceived: _totalReceived,
                      totalSent: _totalSent,
                      onReceivedTap: () => _navigateToRecordList(true),
                      onSentTap: () => _navigateToRecordList(false),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.spacingM),
                ),

                // 横向快捷操作 - 带动画
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _gridAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - _gridAnimation.value)),
                        child: Opacity(
                          opacity: _gridAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: HorizontalQuickActions(
                      items: _buildHorizontalActions(),
                      animationDelay: const Duration(milliseconds: 200), // 从 400ms 优化到 200ms
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.spacingXL),
                ),

                // 最近记录标题 - 带动画
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _listAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _listAnimation.value,
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // 简洁装饰条
                              Container(
                                width: 3,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '最近记录',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_recentGifts.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RecordListScreen(),
                                  ),
                                ).then((_) => refreshData());
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '查看全部',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.spacingS),
                ),

                // 最近记录列表 - 分组时间轴样式
                if (_recentGifts.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else
                  SliverToBoxAdapter(
                    child: GroupedTimeline(
                      gifts: _recentGifts,
                      guestMap: _guestMap,
                      animationDelay: const Duration(milliseconds: 300), // 从 600ms 优化到 300ms
                      onTap: (gift, guest) async {
                        if (!await _verifySecurityLock()) return;
                        _showGiftDetail(gift, guest);
                      },
                      onEdit: (gift, guest) async {
                        if (!await _verifySecurityLock()) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddRecordScreen(
                              editingGift: gift,
                              editingGuest: guest,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadData();
                        }
                      },
                      onDelete: (gift) async {
                        if (!await _verifySecurityLock()) return;
                        await _db.deleteGift(gift.id!);
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已删除')),
                          );
                        }
                      },
                    ),
                  ),

                // 底部间距
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ],
          ),
        ),
      ),
      // FAB 放在 Stack 中，位于底部导航栏上方
      Positioned(
        right: 16,
        bottom: fabBottom,
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddRecordScreen(),
              ),
            );
            if (mounted && result == true) {
              _loadData();
            }
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      child: Row(
        children: [
          const AppLogo(size: 44),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '随礼记',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // 安全锁按钮
          ValueListenableBuilder<bool>(
            valueListenable: _securityService.isUnlocked,
            builder: (context, isUnlocked, child) {
              return Container(
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppTheme.primaryColor.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () async {
                    if (isUnlocked) {
                      _securityService.lock();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('金额已隐藏'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppTheme.primaryColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    } else {
                      await _securityService.ensureUnlocked(context);
                    }
                  },
                  icon: Icon(
                    isUnlocked
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: isUnlocked ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      data: EmptyStates.noRecords(
        onAction: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRecordScreen(),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
      ),
    );
  }
}
