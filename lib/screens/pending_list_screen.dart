import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../services/reminder_service.dart';
import '../services/template_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import '../widgets/custom_toast.dart';
import '../services/export_service.dart';
import '../services/security_service.dart';
import '../utils/security_unlock.dart';
import '../widgets/privacy_aware_text.dart';
import 'add_record_screen.dart';

class PendingListScreen extends StatefulWidget {
  const PendingListScreen({super.key});

  @override
  State<PendingListScreen> createState() => _PendingListScreenState();
}

class _PendingListScreenState extends State<PendingListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storageService = StorageService();
  final _reminderService = ReminderService();
  final _templateService = TemplateService();
  final _exportService = ExportService();
  final _securityService = SecurityService();

  /// 验证安全锁，返回是否通过验证（统一入口）
  Future<bool> _verifySecurityLock() => _securityService.ensureUnlocked(context);

  List<Gift> _unreturnedGifts = [];
  List<Gift> _pendingReceipts = [];
  Map<int, Guest> _guestMap = {};
  bool _isLoading = true;
  
  // 排序选项
  String _sortBy = 'days'; // days, amount, relationship
  bool _sortAscending = false; // false=降序（天数多/金额大优先）

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 监听 StorageService 变化，自动刷新数据
    _storageService.addListener(_onDataChanged);
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
    _storageService.removeListener(_onDataChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 并行加载所有数据，减少等待时间
    final results = await Future.wait([
      _storageService.getUnreturnedGifts(),
      _storageService.getPendingReceipts(),
      _storageService.getAllGuests(),
    ]);

    setState(() {
      _unreturnedGifts = results[0] as List<Gift>;
      _pendingReceipts = results[1] as List<Gift>;
      _guestMap = {for (var g in (results[2] as List<Guest>)) g.id!: g};
      _isLoading = false;
    });
    _sortLists();
  }

  Color _getStatusColor(DateTime date) {
    final days = _reminderService.getDaysPassed(date);
    if (days < 90) return Colors.green;
    if (days < 180) return Colors.orange;
    return Colors.red;
  }

  void _sortLists() {
    setState(() {
      _unreturnedGifts = _sortGiftList(_unreturnedGifts);
      _pendingReceipts = _sortGiftList(_pendingReceipts);
    });
  }

  List<Gift> _sortGiftList(List<Gift> gifts) {
    final sorted = List<Gift>.from(gifts);
    sorted.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'amount':
          result = a.amount.compareTo(b.amount);
          break;
        case 'relationship':
          final guestA = _guestMap[a.guestId];
          final guestB = _guestMap[b.guestId];
          result = (guestA?.relationship ?? '').compareTo(guestB?.relationship ?? '');
          break;
        case 'days':
        default:
          result = a.date.compareTo(b.date);
          break;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('排序方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _buildSortOption('days', '按天数', Icons.schedule),
            _buildSortOption('amount', '按金额', Icons.attach_money),
            _buildSortOption('relationship', '按关系', Icons.people_outline),
            const Divider(),
            ListTile(
              leading: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: AppTheme.primaryColor),
              title: Text(_sortAscending ? '升序（小→大）' : '降序（大→小）'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _sortAscending = !_sortAscending);
                _sortLists();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
      title: Text(label, style: TextStyle(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
      )),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
      onTap: () {
        Navigator.pop(context);
        setState(() => _sortBy = value);
        _sortLists();
      },
    );
  }

  Future<void> _exportCurrentList() async {
    final isUnreturned = _tabController.index == 0;
    final gifts = isUnreturned ? _unreturnedGifts : _pendingReceipts;
    final listType = isUnreturned ? '未还' : '待收';
    
    if (gifts.isEmpty) {
      CustomToast.show(context, '当前清单为空，无需导出');
      return;
    }
    
    try {
      CustomToast.show(context, '正在导出...');
      final path = await _exportService.exportPendingListToExcel(
        gifts: gifts,
        guestMap: _guestMap,
        listType: listType,
      );
      
      if (path != null && mounted) {
        // 尝试分享文件
        await _exportService.shareFile(path);
        if (mounted) {
          CustomToast.show(context, '导出成功：$listType清单');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '导出失败: $e', isError: true);
      }
    }
  }

  String _getDaysText(DateTime date) {
    final days = _reminderService.getDaysPassed(date);
    return '已过${days}天';
  }

  Future<void> _markAsReturned(Gift gift) async {
    final guest = _guestMap[gift.guestId];
    
    // 跳转到新增记录页，预填数据
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecordScreen(
          prefillGuestId: gift.guestId,
          prefillGuestName: guest?.name,
          prefillEventType: gift.eventType,
          prefillAmount: gift.amount,
          prefillIsReceived: !gift.isReceived, // 反向：收礼→送礼，送礼→收礼
          relatedGiftId: gift.id,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _showReminderDialog(Gift gift) async {
    // “提醒话术”仅适用于“待收”（我送礼后希望对方后续回礼）的场景
    if (gift.isReceived) return;

    final guest = _guestMap[gift.guestId];
    if (guest == null) return;

    // 检查提醒次数
    if (gift.remindedCount >= 3) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认提醒'),
          content: const Text('已提醒多次，确认再发？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final templates = await _templateService.getTemplates();
    final useFuzzy = await _templateService.getUseFuzzyAmount();
    if (!mounted) return;

    int selectedIndex = 0;
    bool fuzzyAmount = useFuzzy;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String amount = fuzzyAmount 
            ? _reminderService.fuzzyAmount(gift.amount)
            : '${gift.amount.toStringAsFixed(0)}元';
          
          String previewText = templates[selectedIndex]
            .replaceAll('{对方}', guest.name)
            .replaceAll('{事件}', gift.eventType)
            .replaceAll('{金额}', amount)
            .replaceAll('{我的事件}', '活动');

          return AlertDialog(
            title: const Text('生成提醒话术', style: TextStyle(fontWeight: FontWeight.w800)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模板选择
                  Text('选择模板：', style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  )),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedIndex,
                      underline: const SizedBox(),
                      items: templates.asMap().entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            '模板${e.key + 1}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedIndex = v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 话术预览
                  Text('预览：', style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  )),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      previewText,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 模糊金额开关
                  Row(
                    children: [
                      Checkbox(
                        value: fuzzyAmount,
                        onChanged: (v) {
                          setDialogState(() => fuzzyAmount = v ?? false);
                        },
                      ),
                      const Text('模糊金额（显示为"千把块"）'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  // 复制并分享
                  await Share.share(previewText);
                  // 增加提醒计数
                  await _storageService.incrementRemindedCount(gift.id!);
                  if (context.mounted) {
                    Navigator.pop(context);
                    CustomToast.show(context, '已复制到剪贴板');
                    _loadData();
                  }
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('分享'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditRecord(Gift gift) async {
    final guest = _guestMap[gift.guestId];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecordScreen(
          editingGift: gift,
          editingGuest: guest,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  void _showContextMenu(Gift gift, Offset position) {
    final isReceived = gift.isReceived;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          onTap: () => Future.microtask(() => _markAsReturned(gift)),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(isReceived ? '还账' : '收账'),
            ],
          ),
        ),
        if (!isReceived)
          PopupMenuItem(
            onTap: () => Future.microtask(() => _showReminderDialog(gift)),
            child: Row(
              children: [
                Icon(Icons.message_outlined, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text('提醒一下'),
              ],
            ),
          ),
        PopupMenuItem(
          onTap: () => Future.microtask(() => _openEditRecord(gift)),
          child: const Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(Gift gift) {
    final guest = _guestMap[gift.guestId];
    final statusColor = _getStatusColor(gift.date);
    final isReceived = gift.isReceived;
    final dateFormat = DateFormat('MM月dd日');
    final lunarDate = LunarUtils.getLunarDateString(gift.date);

    final content = Container(
      // margin moved to wrapper Padding to fix Slidable action height
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 状态指示器
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // 信息区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      guest?.name ?? '未知',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        gift.eventType,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(gift.date)} ($lunarDate)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 金额和天数
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PrivacyAwareText(
                '¥${gift.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isReceived ? AppTheme.primaryColor : AppTheme.accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getDaysText(gift.date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // 桌面端使用右键菜单和长按菜单
    return GestureDetector(
      onSecondaryTapUp: (details) async {
        if (!await _verifySecurityLock()) return;
        _showContextMenu(gift, details.globalPosition);
      },
      onLongPressStart: (details) async {
        if (!await _verifySecurityLock()) return;
        _showContextMenu(gift, details.globalPosition);
      },
      onTap: () async {
        if (!await _verifySecurityLock()) return;
        // 如果需要点击查看详情，可以在这里添加逻辑
        // 目前暂时只做点击拦截
      },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Slidable(
                key: ValueKey(gift.id),
                enabled: _securityService.isUnlocked.value, // 未解锁时禁止滑动
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.5, // 适当缩小操作区宽度
                  children: [
                    SlidableAction(
                      onPressed: (_) => _markAsReturned(gift),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      icon: Icons.check_circle_outline,
                      label: isReceived ? '还账' : '收账',
                      borderRadius: BorderRadius.circular(12), // 全圆角
                    ),
                    const SizedBox(width: 8), // 按钮之间的间距
                    SlidableAction(
                      onPressed: (_) => isReceived ? _openEditRecord(gift) : _showReminderDialog(gift),
                      backgroundColor: isReceived ? Colors.grey : (gift.remindedCount > 2 ? Colors.grey : Colors.blue),
                      foregroundColor: Colors.white,
                      icon: isReceived
                          ? Icons.edit_outlined
                          : (gift.remindedCount > 2 ? Icons.warning_amber_outlined : Icons.message_outlined),
                      label: isReceived ? '编辑' : (gift.remindedCount > 2 ? '已提醒' : '提醒'),
                      borderRadius: BorderRadius.circular(12), // 全圆角
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0), // 关键：卡片与侧滑按钮之间的间距
                  child: content,
                ),
              ),
            ),    );
  }

  Widget _buildEmptyState(bool isUnreturned) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUnreturned ? Icons.inbox_outlined : Icons.outbox_outlined,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isUnreturned ? '暂无待还人情' : '暂无待收人情',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待处理人情', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortMenu,
            tooltip: '排序',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCurrentList,
            tooltip: '导出当前清单',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '未还 (${_unreturnedGifts.length})'),
            Tab(text: '待收 (${_pendingReceipts.length})'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 未还清单
                _unreturnedGifts.isEmpty
                    ? _buildEmptyState(true)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _securityService.isUnlocked,
                          builder: (context, isUnlocked, child) {
                             return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _unreturnedGifts.length,
                              itemBuilder: (context, index) => _buildListItem(_unreturnedGifts[index]),
                            );
                          },
                        ),
                      ),
                // 待收清单
                _pendingReceipts.isEmpty
                    ? _buildEmptyState(false)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _securityService.isUnlocked,
                          builder: (context, isUnlocked, child) {
                             return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _pendingReceipts.length,
                              itemBuilder: (context, index) => _buildListItem(_pendingReceipts[index]),
                            );
                          },
                        ),
                      ),
              ],
            ),
    );
  }
}
