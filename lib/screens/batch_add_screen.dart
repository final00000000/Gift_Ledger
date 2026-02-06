import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import '../widgets/custom_toast.dart';
import '../widgets/lunar_calendar_picker.dart';

class BatchAddScreen extends StatefulWidget {
  final EventBook eventBook;

  const BatchAddScreen({super.key, required this.eventBook});

  @override
  State<BatchAddScreen> createState() => _BatchAddScreenState();
}

class _BatchRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  bool isReceived = true;
  String relationship = RelationshipTypes.friend;
  DateTime? customDate; // If null, use event book date
  String key = UniqueKey().toString();

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _BatchAddScreenState extends State<BatchAddScreen> {
  final StorageService _db = StorageService();
  final List<_BatchRow> _rows = [];
  bool _isSaving = false;
  
  // Header display only
  late DateTime _defaultDate;
  late String _defaultEventType;

  @override
  void initState() {
    super.initState();
    _defaultDate = widget.eventBook.date;
    _defaultEventType = widget.eventBook.type;
    // Initial rows
    for (int i = 0; i < 3; i++) {
      _addNewRow();
    }
  }

  @override
  void dispose() {
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addNewRow() {
    setState(() {
      _rows.add(_BatchRow());
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      final row = _rows.removeAt(index);
      row.dispose();
    });
  }

  void _selectRowDate(_BatchRow row) async {
    final DateTime initial = row.customDate ?? _defaultDate;
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => LunarCalendarPicker(
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      ),
    );
    if (picked != null) {
      setState(() => row.customDate = picked);
    }
  }

  void _selectRowRelationship(_BatchRow row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            const Text('选择关系', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: RelationshipTypes.all.map((t) {
                final isSelected = t == row.relationship;
                return ChoiceChip(
                  label: Text(t),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => row.relationship = t);
                      Navigator.pop(context);
                    }
                  },
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.grey[100],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);

    try {
      final List<Gift> giftsToInsert = [];
      final List<Guest> guestsToInsert = [];

      // Validation
      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final name = row.nameController.text.trim();
        final amountStr = row.amountController.text.trim();

        if (name.isEmpty && amountStr.isEmpty) continue;

        if (name.isEmpty) {
          throw Exception('第 ${i + 1} 行缺少姓名');
        }

        final amount = double.tryParse(amountStr);
        if (amount == null || amount <= 0) {
          throw Exception('第 ${i + 1} 行金额无效');
        }
      }

      // Fetch all guests for lookup (一次性查询)
      final existingGuests = await _db.getAllGuests();
      final guestMap = {for (var g in existingGuests) g.name: g};
      final newGuestNames = <String>{};

      // 第一遍：收集需要创建的新客人
      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final name = row.nameController.text.trim();
        final amountStr = row.amountController.text.trim();

        if (name.isEmpty && amountStr.isEmpty) continue;

        if (!guestMap.containsKey(name) && !newGuestNames.contains(name)) {
          newGuestNames.add(name);
          guestsToInsert.add(Guest(name: name, relationship: row.relationship));
        }
      }

      // 批量插入新客人
      if (guestsToInsert.isNotEmpty) {
        for (final guest in guestsToInsert) {
          final guestId = await _db.insertGuest(guest);
          if (guestId > 0) {
            guestMap[guest.name] = guest.copyWith(id: guestId);
          }
        }
      }

      // 第二遍：创建礼金记录
      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final name = row.nameController.text.trim();
        final amountStr = row.amountController.text.trim();

        if (name.isEmpty && amountStr.isEmpty) continue;

        final amount = double.parse(amountStr);
        final guestId = guestMap[name]!.id!;

        giftsToInsert.add(Gift(
          guestId: guestId,
          amount: amount,
          isReceived: row.isReceived,
          eventType: _defaultEventType,
          eventBookId: widget.eventBook.id,
          date: row.customDate ?? _defaultDate,
        ));
      }

      if (giftsToInsert.isEmpty) {
         throw Exception('没有有效数据');
      }

      // 批量插入礼金记录（一次性插入）
      await _db.insertGiftsBatch(giftsToInsert);

      if (mounted) {
        CustomToast.show(context, '成功录入 ${giftsToInsert.length} 条记录');
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '保存失败: ${e.toString().replaceAll("Exception: ", "")}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('批量录入', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isSaving ? null : _saveAll,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isSaving 
                 ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                 : const Text('保存', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Card (Read Only)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.book_rounded, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _defaultEventType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                           Text(
                            DateFormat('yyyy.MM.dd').format(_defaultDate),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LunarUtils.getLunarDateString(_defaultDate),
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('默认', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Rows List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _rows.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildCompactRow(index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewRow,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCompactRow(int index) {
    final row = _rows[index];
    final dateStr = row.customDate == null ? '默认日期' : DateFormat('MM.dd').format(row.customDate!);
    final isCustomDate = row.customDate != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Index | Name | Amount
          Row(
            children: [
              // Index
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              
              // Name
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: row.nameController,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLength: 20,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\d\s]')), // No digits or spaces
                    ],
                    decoration: const InputDecoration(
                      hintText: '姓名',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '', // Hide character counter
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Amount
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: row.amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')), // Digits only, max 2 decimals
                    ],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    decoration: const InputDecoration(
                      hintText: '金额',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      prefixText: '¥',
                      prefixStyle: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2: Relationship | Date | Type | Delete
          Row(
            children: [
              // Relationship
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _selectRowRelationship(row),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            row.relationship,
                            style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Date
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _selectRowDate(row),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isCustomDate ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: isCustomDate ? AppTheme.primaryColor : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: isCustomDate ? AppTheme.primaryColor : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: isCustomDate ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Type (Receive/Send)
              GestureDetector(
                onTap: () => setState(() => row.isReceived = !row.isReceived),
                child: Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: row.isReceived ? const Color(0xFFFFECEC) : const Color(0xFFE6FFFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: row.isReceived ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      row.isReceived ? '收礼' : '送礼',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: row.isReceived ? AppTheme.primaryColor : AppTheme.accentColor,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Delete
              GestureDetector(
                onTap: () => _removeRow(index),
                child: Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey[300]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
