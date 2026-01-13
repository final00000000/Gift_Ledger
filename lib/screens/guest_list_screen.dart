import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'add_record_screen.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key});

  @override
  GuestListScreenState createState() => GuestListScreenState();
}

class GuestListScreenState extends State<GuestListScreen> {
  final StorageService _db = StorageService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Guest> _guests = [];
  List<Guest> _filteredGuests = [];
  Map<int, double> _receivedTotals = {};
  Map<int, double> _sentTotals = {};
  String? _selectedRelationship;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterGuests);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final guests = await _db.getAllGuests();
      final receivedTotals = await _db.getGuestReceivedTotals();
      final sentTotals = await _db.getGuestSentTotals();

      if (mounted) {
        setState(() {
          _guests = guests;
          _filteredGuests = guests;
          _receivedTotals = receivedTotals;
          _sentTotals = sentTotals;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading guests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 公开的刷新方法
  void refreshData() {
    _loadData();
  }

  void _filterGuests() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredGuests = _guests.where((guest) {
        final matchesName = guest.name.toLowerCase().contains(query);
        final matchesRelationship = _selectedRelationship == null ||
            guest.relationship == _selectedRelationship;
        return matchesName && matchesRelationship;
      }).toList();
    });
  }

  void _selectRelationship(String? relationship) {
    setState(() {
      _selectedRelationship = relationship;
    });
    _filterGuests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 标题和搜索
            _buildHeader(),
            // 筛选器
            _buildFilters(),
            // 列表
            Expanded(
              child: _isLoading
                  ? const LoadingWidget(message: '加载联系人...')
                  : _filteredGuests.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppTheme.primaryColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _filteredGuests.length,
                            itemBuilder: (context, index) {
                              return _buildGuestCard(_filteredGuests[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '礼尚往来',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.spacingM),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索姓名...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _filterGuests();
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('全部', null),
          const SizedBox(width: AppTheme.spacingS),
          ...RelationshipTypes.all.map((type) {
            return Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingS),
              child: _buildFilterChip(type, type),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedRelationship == value;
    return GestureDetector(
      onTap: () => _selectRelationship(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGuestCard(Guest guest) {
    final received = _receivedTotals[guest.id] ?? 0;
    final sent = _sentTotals[guest.id] ?? 0;
    
    // 计算还礼进度
    double progress = 0;
    String statusText = '';
    Color statusColor = AppTheme.textSecondary;

    if (received > 0 && sent >= received) {
      progress = 1;
      statusText = '已还礼';
      statusColor = AppTheme.successColor;
    } else if (received > 0) {
      progress = sent / received;
      statusText = '待还礼';
      statusColor = AppTheme.warningColor;
    } else if (sent > 0) {
      progress = 0;
      statusText = '待收礼';
      statusColor = AppTheme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGuestDetail(guest),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                Row(
                  children: [
                    // 头像
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          guest.name.isNotEmpty ? guest.name[0] : '?',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    // 信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                guest.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              child: Text(
                                  guest.relationship,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          Row(
                            children: [
                              Text(
                                '收 ¥${received.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Text(
                                '送 ¥${sent.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 状态
                    if (statusText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                // 进度条
                if (received > 0) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1 ? AppTheme.successColor : AppTheme.primaryColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty) {
      return EmptyStateWidget(
        data: EmptyStates.searchNoResult(_searchController.text),
      );
    }
    return EmptyStateWidget(
      data: EmptyStates.noGuests(
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

  Future<void> _showGuestDetail(Guest guest) async {
    final gifts = await _db.getGiftsByGuest(guest.id!);
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GuestDetailSheet(
        guest: guest,
        gifts: gifts,
        onDelete: () async {
          await _db.deleteGuest(guest.id!);
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }
}

class _GuestDetailSheet extends StatelessWidget {
  final Guest guest;
  final List<Gift> gifts;
  final VoidCallback onDelete;

  const _GuestDetailSheet({
    required this.guest,
    required this.gifts,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        children: [
          // 把手
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      guest.name[0],
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guest.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        guest.relationship,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('确定要删除"${guest.name}"的所有记录吗?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                            child: const Text(
                              '删除',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: AppTheme.spacingL),
          // 历史记录
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: Row(
              children: [
                Text(
                  '历史记录',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  '(${gifts.length}条)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Expanded(
            child: gifts.isEmpty
                ? Center(
                    child: Text(
                      '暂无记录',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: gifts.length,
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: gift.isReceived
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : AppTheme.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Icon(
                            gift.isReceived
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: gift.isReceived
                                ? AppTheme.primaryColor
                                : AppTheme.accentColor,
                          ),
                        ),
                        title: Text(
                          '${gift.isReceived ? "收礼" : "送礼"} · ${gift.eventType}',
                        ),
                        subtitle: Text(
                          '${gift.date.year}年${gift.date.month}月${gift.date.day}日',
                        ),
                        trailing: Text(
                          '${gift.isReceived ? "+" : "-"}¥${gift.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: gift.isReceived
                                ? AppTheme.primaryColor
                                : AppTheme.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
