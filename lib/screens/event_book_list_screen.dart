import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_book.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/lunar_utils.dart';
import '../widgets/event_book_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/lunar_calendar_picker.dart';
import 'event_book_detail_screen.dart';

class EventBookListScreen extends StatefulWidget {
  const EventBookListScreen({super.key});

  @override
  State<EventBookListScreen> createState() => _EventBookListScreenState();
}

class _EventBookListScreenState extends State<EventBookListScreen> {
  final StorageService _db = StorageService();
  List<EventBook> _eventBooks = [];
  Map<int, int> _giftCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final books = await _db.getAllEventBooks();
      
      // Load gift counts for each book
      final counts = <int, int>{};
      for (var book in books) {
        if (book.id != null) {
          counts[book.id!] = await _db.getEventBookGiftCount(book.id!);
        }
      }

      if (mounted) {
        setState(() {
          _eventBooks = books;
          _giftCounts = counts;
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

  void _showCreateOrEditDialog([EventBook? eventBook]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventBookForm(
        eventBook: eventBook,
        onSubmit: (newBook) async {
          try {
            if (eventBook == null) {
              await _db.insertEventBook(newBook);
            } else {
              await _db.updateEventBook(newBook);
            }
            if (mounted) {
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(eventBook == null ? '已创建' : '已更新')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('保存失败: $e')),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(EventBook eventBook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除活动簿 "${eventBook.name}" 吗？\n删除后，该活动簿下的所有礼金记录也将一并删除，且不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _db.deleteEventBook(eventBook.id!);
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
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
      appBar: AppBar(
        title: const Text('活动簿', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _eventBooks.isEmpty
              ? EmptyStateWidget(
                  data: EmptyStateData(
                    icon: Icons.book_outlined,
                    title: '暂无活动簿',
                    subtitle: '点击下方按钮新建活动簿',
                    actionText: '新建活动簿',
                    onAction: () => _showCreateOrEditDialog(),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _eventBooks.length,
                    itemBuilder: (context, index) {
                      final book = _eventBooks[index];
                      return EventBookCard(
                        eventBook: book,
                        giftCount: _giftCounts[book.id] ?? 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventBookDetailScreen(eventBook: book),
                            ),
                          ).then((_) => _loadData());
                        },
                        onEdit: () => _showCreateOrEditDialog(book),
                        onDelete: () => _confirmDelete(book),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOrEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EventBookForm extends StatefulWidget {
  final EventBook? eventBook;
  final Function(EventBook) onSubmit;

  const _EventBookForm({this.eventBook, required this.onSubmit});

  @override
  State<_EventBookForm> createState() => _EventBookFormState();
}

class _EventBookFormState extends State<_EventBookForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.eventBook != null) {
      _nameController.text = widget.eventBook!.name;
      _typeController.text = widget.eventBook!.type;
      _noteController.text = widget.eventBook!.note ?? '';
      _selectedDate = widget.eventBook!.date;
    } else {
       // Default values for new book
       _typeController.text = '酒席'; // Common default
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => LunarCalendarPicker(
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  InputDecoration _buildInputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryColor) : null,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lunarStr = LunarUtils.getLunarDateString(_selectedDate);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.eventBook == null ? '新建活动簿' : '编辑活动簿',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration(
                    '活动名称',
                    hint: '例如：我的婚礼、孩子满月',
                    icon: Icons.celebration,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入活动名称';
                    }
                    if (value.length > 30) return '名称不能超过30个字';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Type field
                TextFormField(
                  controller: _typeController,
                  decoration: _buildInputDecoration(
                    '类型',
                    hint: '酒席、宴会...',
                    icon: Icons.local_activity,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入类型';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Date picker
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '活动日期',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('yyyy年MM月dd日').format(_selectedDate)} ($lunarStr)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Note field
                TextFormField(
                  controller: _noteController,
                  decoration: _buildInputDecoration(
                    '备注 (可选)',
                    icon: Icons.notes,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final lunar = LunarUtils.getLunarDateString(_selectedDate);
                      final book = widget.eventBook?.copyWith(
                        name: _nameController.text.trim(),
                        type: _typeController.text.trim(),
                        date: _selectedDate,
                        lunarDate: lunar,
                        note: _noteController.text.trim(),
                      ) ?? EventBook(
                        name: _nameController.text.trim(),
                        type: _typeController.text.trim(),
                        date: _selectedDate,
                        lunarDate: lunar,
                        note: _noteController.text.trim(),
                      );
                      widget.onSubmit(book);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
