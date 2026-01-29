import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gift_list_item.dart';
import '../widgets/empty_state.dart';
import '../utils/lunar_utils.dart';
import '../services/security_service.dart';
import '../widgets/pin_code_dialog.dart';
import '../widgets/privacy_aware_text.dart';
import 'add_record_screen.dart';
import 'batch_add_screen.dart';

class EventBookDetailScreen extends StatefulWidget {
  final EventBook eventBook;

  const EventBookDetailScreen({super.key, required this.eventBook});

  @override
  State<EventBookDetailScreen> createState() => _EventBookDetailScreenState();
}

class _EventBookDetailScreenState extends State<EventBookDetailScreen> {
  final StorageService _db = StorageService();
  final SecurityService _securityService = SecurityService();

  /// 验证安全锁，返回是否通过验证
  Future<bool> _verifySecurityLock() async {
    if (!_securityService.isUnlocked.value) {
      return await PinCodeDialog.show(context);
    }
    return true;
  }

  List<Gift> _gifts = [];
  Map<int, Guest> _guestMap = {};
  double _totalReceived = 0;
  double _totalSent = 0;
  bool _isLoading = true;

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
      final eventBookId = widget.eventBook.id;
      if (eventBookId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final gifts = await _db.getGiftsByEventBook(eventBookId);
      final received = await _db.getEventBookReceivedTotal(eventBookId);
      final sent = await _db.getEventBookSentTotal(eventBookId);
      final guests = await _db.getAllGuests();

      if (mounted) {
        setState(() {
          _gifts = gifts;
          _totalReceived = received;
          _totalSent = sent;
          _guestMap = {for (var g in guests) g.id!: g};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppTheme.primaryColor),
              ),
              title: const Text('单条录入'),
              subtitle: const Text('常规方式，详细记录'),
              onTap: () async {
                Navigator.pop(context); // Close sheet
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddRecordScreen(initialEventBookId: widget.eventBook.id),
                  ),
                );
                if (result == true) _loadData();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.playlist_add, color: Colors.orange),
              ),
              title: const Text('批量录入 (开发中)'),
              subtitle: const Text('快速添加多条记录'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BatchAddScreen(eventBook: widget.eventBook),
                  ),
                );
                if (result == true) _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventBook.name),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Header
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('收礼总额', _totalReceived, isReceived: true),
                          Container(width: 1, height: 30, color: Colors.grey[100]),
                          _buildStatItem('送礼总额', _totalSent, isReceived: false),
                          Container(width: 1, height: 30, color: Colors.grey[100]),
                          Column(
                            children: [
                              Text(
                                _gifts.length.toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Text(
                                '记录数',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (widget.eventBook.note != null && widget.eventBook.note!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded, size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.eventBook.note!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary.withOpacity(0.8),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 3, height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('礼金明细', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
                // List
                Expanded(
                      child: _gifts.isEmpty
                          ? EmptyStateWidget(
                              data: EmptyStateData(
                                icon: Icons.receipt_long_outlined,
                                title: '暂无礼金记录',
                                subtitle: '点击下方按钮开始录入',
                                actionText: '立即录入',
                                onAction: _showAddMenu,
                              ),
                            )
                          : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          itemCount: _gifts.length,
                          itemBuilder: (context, index) {
                            final gift = _gifts[index];
                            return GiftListItem(
                              gift: gift,
                              guest: _guestMap[gift.guestId],
                              onTap: () async {
                                if (!await _verifySecurityLock()) return;
                                _showGiftDetail(gift, _guestMap[gift.guestId]);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        label: const Text('记一笔'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, {required bool isReceived}) {
    return Column(
      children: [
        PrivacyAwareText(
          amount.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isReceived ? AppTheme.primaryColor : AppTheme.accentColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
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
                      if (result == true) _loadData();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
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
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
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
}
