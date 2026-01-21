import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import '../widgets/balance_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/gift_list_item.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_logo.dart';
import 'add_record_screen.dart';
import 'record_list_screen.dart';
import 'pending_list_screen.dart';
import 'event_book_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final StorageService _db = StorageService();
  double _totalReceived = 0;
  double _totalSent = 0;
  List<Gift> _recentGifts = [];
  Map<int, Guest> _guestMap = {};
  bool _isLoading = true;
  int _pendingCount = 0;  // 待处理数量
  bool _eventBooksEnabled = true;
  bool _showHomeAmounts = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final includeEventBooks = await _db.getStatsIncludeEventBooks();
      final eventBooksEnabled = await _db.getEventBooksEnabled();
      final showHomeAmounts = await _db.getShowHomeAmounts();
      
      // 并行加载所有数据
      final results = await Future.wait([
        _db.getTotalReceived(includeEventBooks: includeEventBooks),
        _db.getTotalSent(includeEventBooks: includeEventBooks),
        _db.getRecentGifts(limit: 10),
        _db.getAllGuests(),
        _db.getPendingCount(includeEventBooks: includeEventBooks),
      ]);

      if (mounted) {
        setState(() {
          _totalReceived = results[0] as double;
          _totalSent = results[1] as double;
          _recentGifts = results[2] as List<Gift>;
          final guests = results[3] as List<Guest>;
          _guestMap = {for (var g in guests) g.id!: g};
          _pendingCount = results[4] as int;
          _eventBooksEnabled = eventBooksEnabled;
          _showHomeAmounts = showHomeAmounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      final eventBooksEnabled = await _db.getEventBooksEnabled();
      final showHomeAmounts = await _db.getShowHomeAmounts();
      if (mounted) {
        setState(() {
          _eventBooksEnabled = eventBooksEnabled;
          _showHomeAmounts = showHomeAmounts;
          _isLoading = false;
        });
      }
    }
  }

  // 公开的刷新方法
  void refreshData() {
    _loadData();
  }

  // 导航到详情列表
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
    ).then((_) {
      // 返回时刷新数据
      refreshData();
    });
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
                  color: Colors.grey.withOpacity(0.3),
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
                    color: itemColor.withOpacity(0.1),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            slivers: [
              if (_isLoading && _recentGifts.isEmpty)
                SliverFillRemaining(
                  child: DashboardSkeleton(),
                )
              else ...[
                // 标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingL,
                      AppTheme.spacingL,
                      AppTheme.spacingL,
                      AppTheme.spacingS,
                    ),
                    child: Row(
                      children: [
                        const AppLogo(size: 48),
                        const SizedBox(width: AppTheme.spacingM),
                        Text(
                          '随礼记',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Spacer(),
                        // 待处理入口
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PendingListScreen(),
                              ),
                            ).then((_) => refreshData());
                          },
                          icon: Badge(
                            isLabelVisible: _pendingCount > 0,
                            label: Text('$_pendingCount'),
                            child: const Icon(Icons.pending_actions_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 收支卡片 - 添加点击事件
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: BalanceCard(
                      totalReceived: _totalReceived,
                      totalSent: _totalSent,
                      showAmounts: _showHomeAmounts,
                      onReceivedTap: () => _navigateToRecordList(true),
                      onSentTap: () => _navigateToRecordList(false),
                    ),
                  ),
                ),
                if (_eventBooksEnabled)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL, vertical: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EventBookListScreen(),
                              ),
                            ).then((_) => refreshData());
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.book, color: Colors.purple),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '活动簿',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '管理婚礼、满月酒等特定活动的礼金',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 最近记录标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingL,
                      AppTheme.spacingL,
                      AppTheme.spacingL,
                      AppTheme.spacingXS,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '最近记录',
                          style: Theme.of(context).textTheme.titleLarge,
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
                            child: const Text('查看全部'),
                          ),
                      ],
                    ),
                  ),
                ),
                // 最近记录列表
                if (_recentGifts.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final gift = _recentGifts[index];
                          final guest = _guestMap[gift.guestId];
                          return RepaintBoundary(
                            child: GiftListItem(
                              gift: gift,
                              guest: guest,
                              onTap: () => _showGiftDetail(gift, guest),
                            ),
                          );
                        },
                        childCount: _recentGifts.length,
                      ),
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
