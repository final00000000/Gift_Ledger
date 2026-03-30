import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../services/dashboard_computation_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import '../widgets/dashboard/dashboard_empty_state.dart';
import '../widgets/dashboard/dashboard_fab.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/dashboard_recent_section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/hero_section.dart';
import '../widgets/horizontal_quick_actions.dart';
import '../widgets/grouped_timeline.dart';
import '../services/security_service.dart';
import '../utils/security_unlock.dart';
import 'add_record_screen.dart';
import 'record_list_screen.dart';
import 'pending_list_screen.dart';
import 'event_book_list_screen.dart';

class DashboardPreviewData {
  const DashboardPreviewData({
    this.totalReceived = 0,
    this.totalSent = 0,
    this.recentGifts = const <Gift>[],
    this.guestMap = const <int, Guest>{},
    this.pendingCount = 0,
    this.eventBooksEnabled = true,
  });

  final double totalReceived;
  final double totalSent;
  final List<Gift> recentGifts;
  final Map<int, Guest> guestMap;
  final int pendingCount;
  final bool eventBooksEnabled;

  DashboardSnapshot toSnapshot() {
    return DashboardSnapshot(
      totalReceived: totalReceived,
      totalSent: totalSent,
      recentGifts: recentGifts,
      guestMap: guestMap,
      pendingCount: pendingCount,
      eventBooksEnabled: eventBooksEnabled,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.previewData,
  });

  final DashboardPreviewData? previewData;

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _entranceAnimationDuration = Duration(milliseconds: 360);
  static const Duration _gridAnimationDelay = Duration(milliseconds: 120);
  static const double _headerAnimationOffset = 12;
  static const double _heroAnimationOffset = 16;
  static const double _gridAnimationOffset = 16;

  final StorageService _db = StorageService();
  final DashboardComputationService _dashboardComputationService =
      const DashboardComputationService();
  final SecurityService _securityService = SecurityService();
  double _totalReceived = 0;
  double _totalSent = 0;
  List<Gift> _recentGifts = [];
  Map<int, Guest> _guestMap = {};
  DashboardSnapshot? _snapshot;
  late List<HorizontalActionItem> _quickActions;
  bool _isLoading = true;
  bool _isFirstLoad = true;

  late AnimationController _animationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _heroAnimation;
  late Animation<double> _gridAnimation;

  /// 验证安全锁，返回是否通过验证（统一入口，避免各页面重复实现）
  Future<bool> _verifySecurityLock() =>
      _securityService.ensureUnlocked(context);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    final previewData = widget.previewData;
    if (previewData != null) {
      _applyPreviewData(previewData);
      return;
    }

    _quickActions = const <HorizontalActionItem>[];
    _db.addListener(_onDataChanged);
    _loadData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: _entranceAnimationDuration,
    );

    _headerAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.36, curve: Curves.easeOutCubic),
    );

    _heroAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.12, 0.58, curve: Curves.easeOutCubic),
    );

    _gridAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.24, 1.0, curve: Curves.easeOutCubic),
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
    if (widget.previewData == null) {
      _db.removeListener(_onDataChanged);
    }
    super.dispose();
  }

  void _applyPreviewData(DashboardPreviewData previewData) {
    final snapshot = previewData.toSnapshot();
    _totalReceived = snapshot.totalReceived;
    _totalSent = snapshot.totalSent;
    _recentGifts = snapshot.recentGifts;
    _guestMap = snapshot.guestMap;
    _snapshot = snapshot;
    _quickActions = _createQuickActions(snapshot);
    _isLoading = false;
  }

  List<HorizontalActionItem> _createQuickActions(DashboardSnapshot snapshot) {
    final items = <HorizontalActionItem>[];

    if (snapshot.eventBooksEnabled) {
      items.add(
        HorizontalActionItem(
          title: '活动簿',
          icon: Icons.book_rounded,
          color: AppTheme.eventBookColor,
          onTap: _openEventBooks,
        ),
      );
    }

    items.add(
      HorizontalActionItem(
        title: '待处理',
        icon: Icons.pending_actions_rounded,
        color: AppTheme.pendingColor,
        badge: snapshot.pendingCount > 0 ? snapshot.pendingCount : null,
        onTap: _openPendingList,
      ),
    );

    items.add(
      HorizontalActionItem(
        title: '记录',
        icon: Icons.list_alt_rounded,
        color: const Color(0xFF06B6D4),
        onTap: _openRecordList,
      ),
    );

    return List.unmodifiable(items);
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
        final snapshot = _dashboardComputationService.buildSnapshot(
          totalReceived: results[0] as double,
          totalSent: results[1] as double,
          recentGifts: results[2] as List<Gift>,
          guests: results[3] as List<Guest>,
          pendingCount: results[4] as int,
          eventBooksEnabled: eventBooksEnabled,
        );

        setState(() {
          _totalReceived = snapshot.totalReceived;
          _totalSent = snapshot.totalSent;
          _recentGifts = snapshot.recentGifts;
          _guestMap = snapshot.guestMap;
          _snapshot = snapshot;
          _quickActions = _createQuickActions(snapshot);
          _isLoading = false;
        });

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
          _snapshot = DashboardSnapshot(
            totalReceived: _totalReceived,
            totalSent: _totalSent,
            recentGifts: _recentGifts,
            guestMap: _guestMap,
            pendingCount: _snapshot?.pendingCount ?? 0,
            eventBooksEnabled: eventBooksEnabled,
          );
          _quickActions = _createQuickActions(_snapshot!);
          _isLoading = false;
        });
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

  void _openEventBooks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EventBookListScreen(),
      ),
    ).then((_) => refreshData());
  }

  void _openPendingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PendingListScreen(),
      ),
    ).then((_) => refreshData());
  }

  void _openRecordList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordListScreen(),
      ),
    ).then((_) => refreshData());
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

          final tween = Tween(begin: begin, end: end).chain(
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

  Future<void> _handleSecurityPressed(bool isUnlocked) async {
    if (isUnlocked) {
      _securityService.lock();
      if (!mounted) return;
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
      return;
    }

    await _securityService.ensureUnlocked(context);
  }

  Future<void> _openAddRecord() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecordScreen(),
      ),
    );
    if (mounted && result == true) {
      _loadData();
    }
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
                      final navigator = Navigator.of(context);
                      if (!await _verifySecurityLock()) return;
                      if (!mounted) return;

                      navigator.pop();
                      final result = await navigator.push(
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
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (!await _verifySecurityLock()) return;
                      if (!mounted) return;

                      navigator.pop();
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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

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


  Widget _buildEntranceTransition({
    required Animation<double> animation,
    required double offset,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, animatedChild) {
          return Transform.translate(
            offset: Offset(0, offset * (1 - animation.value)),
            child: animatedChild,
          );
        },
      ),
    );
  }

  Widget _buildSecurityAwareSummary() {
    return ValueListenableBuilder<bool>(
      valueListenable: _securityService.isUnlocked,
      builder: (context, isUnlocked, _) {
        return SliverList(
          delegate: SliverChildListDelegate.fixed([
            _buildEntranceTransition(
              animation: _headerAnimation,
              offset: _headerAnimationOffset,
              child: RepaintBoundary(
                child: DashboardHeader(
                  isUnlocked: isUnlocked,
                  onSecurityPressed: () => _handleSecurityPressed(isUnlocked),
                ),
              ),
            ),
            _buildEntranceTransition(
              animation: _heroAnimation,
              offset: _heroAnimationOffset,
              child: RepaintBoundary(
                child: HeroSection(
                  totalReceived: _totalReceived,
                  totalSent: _totalSent,
                  isUnlocked: isUnlocked,
                  onReceivedTap: () => _navigateToRecordList(true),
                  onSentTap: () => _navigateToRecordList(false),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final quickActions = _snapshot == null ? const <HorizontalActionItem>[] : _quickActions;

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
                    _buildSecurityAwareSummary(),
                    SliverToBoxAdapter(
                      child: _buildEntranceTransition(
                        animation: _gridAnimation,
                        offset: _gridAnimationOffset,
                        child: RepaintBoundary(
                          child: HorizontalQuickActions(
                            items: quickActions,
                            animationDelay: _gridAnimationDelay,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppTheme.spacingXL),
                    ),
                    SliverToBoxAdapter(
                      child: DashboardRecentSectionHeader(
                        hasRecords: _recentGifts.isNotEmpty,
                        onViewAll: _openRecordList,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppTheme.spacingS),
                    ),
                    if (_recentGifts.isEmpty)
                      SliverFillRemaining(
                        child: DashboardEmptyState(onAddRecord: _openAddRecord),
                      )
                    else
                      SliverToBoxAdapter(
                        child: GroupedTimeline(
                          gifts: _recentGifts,
                          guestMap: _guestMap,
                          enableAnimations: false,
                          onTap: (gift, guest) async {
                            if (!await _verifySecurityLock()) return;
                            _showGiftDetail(gift, guest);
                          },
                          onEdit: (gift, guest) async {
                            final navigator = Navigator.of(context);
                            if (!await _verifySecurityLock()) return;
                            final result = await navigator.push(
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
                            final messenger = ScaffoldMessenger.of(context);
                            if (!await _verifySecurityLock()) return;
                            await _db.deleteGift(gift.id!);
                            _loadData();
                            if (!mounted) return;

                            messenger.showSnackBar(
                              const SnackBar(content: Text('已删除')),
                            );
                          },
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 120),
                    ),
                  ],
                ],
              ),
            ),
          ),
          DashboardFab(
            bottomPadding: bottomPadding,
            onPressed: _openAddRecord,
          ),
        ],
      ),
    );
  }
}
