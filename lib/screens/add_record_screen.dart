import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/custom_numpad.dart';
import '../widgets/lunar_calendar_picker.dart';


class AddRecordScreen extends StatefulWidget {
  final Gift? editingGift;
  final Guest? editingGuest;

  const AddRecordScreen({
    super.key,
    this.editingGift,
    this.editingGuest,
  });

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final StorageService _db = StorageService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  String _amount = '0';
  bool _isReceived = true;
  String _eventType = EventTypes.wedding;
  String _relationship = RelationshipTypes.friend;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  List<Guest> _existingGuests = [];
  List<Guest> _filteredGuests = [];
  bool _showSuggestions = false;

  final LayerLink _nameLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showNumpad = false;  // 控制数字键盘显示状态
  final FocusNode _nameFocusNode = FocusNode(); // 添加 FocusNode

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadGuests();
    _nameController.addListener(_onNameChanged);
    _nameFocusNode.addListener(_onFocusChanged);
    
    // 如果是编辑模式，初始化数据
    if (widget.editingGift != null) {
      _initializeEditMode();
    }
  }

  void _initializeEditMode() {
    final gift = widget.editingGift!;
    final guest = widget.editingGuest;
    
    setState(() {
      _amount = gift.amount.toStringAsFixed(0);
      _isReceived = gift.isReceived;
      _eventType = gift.eventType;
      _selectedDate = gift.date;
      if (gift.note != null) {
        _noteController.text = gift.note!;
      }
      
      if (guest != null) {
        _nameController.text = guest.name;
        _relationship = guest.relationship;
      }
    });
  }

  void _onFocusChanged() {
    if (!_nameFocusNode.hasFocus) {
      // 延迟隐藏，以便点击事件能先触?
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_nameFocusNode.hasFocus) {
          _hideOverlay();
        }
      });
    } else {
        // 获得焦点时，如果有内容则显示建议
        if (_nameController.text.isNotEmpty && _filteredGuests.isNotEmpty) {
            _showOverlay();
        }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isReceived = prefs.getBool('default_is_received') ?? true;
    });
  }

  Future<void> _loadGuests() async {
    _existingGuests = await _db.getAllGuests();
  }

  void _onNameChanged() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _hideOverlay();
      setState(() {
        _filteredGuests = [];
        _showSuggestions = false;
      });
    } else {
      _filteredGuests = _existingGuests
          .where((g) => g.name.toLowerCase().contains(query))
          .take(5)
          .toList();
      setState(() {
        _showSuggestions = _filteredGuests.isNotEmpty;
      });
      if (_showSuggestions && _nameFocusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    }
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 2 * AppTheme.spacingL - 40,
        child: CompositedTransformFollower(
          link: _nameLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56), // 输入框高?+ 间距
          child: Material(
            elevation: 20,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: _filteredGuests.map((g) => ListTile(
                    leading: const Icon(Icons.person_search_rounded, color: AppTheme.primaryColor),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(g.relationship, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      _selectGuest(g);
                    },
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectGuest(Guest guest) {
    setState(() {
      _nameController.text = guest.name;
      _relationship = guest.relationship;
    });
    _hideOverlay();
    // 选择后可能需要收起键盘或者保持焦?
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _hideOverlay();
    _nameController.dispose();
    _noteController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    setState(() {
      if (digit == '.') {
        if (!_amount.contains('.')) {
          _amount = _amount == '0' ? '0.' : '$_amount.';
        }
      } else {
        if (_amount == '0') {
          _amount = digit;
        } else {
          if (_amount.contains('.')) {
            final parts = _amount.split('.');
            if (parts[1].length < 2) {
              _amount += digit;
            }
          } else if (_amount.length < 8) {
            _amount += digit;
          }
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
        if (_amount.endsWith('.')) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else {
        _amount = '0';
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
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

  Widget _buildConfirmationRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        Text(
          value, 
          style: TextStyle(
            color: isHighlight ? AppTheme.primaryColor : AppTheme.textPrimary, 
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
            fontSize: isHighlight ? 24 : 16,
          ),
        ),
      ],
    );
  }

  Future<void> _saveRecord() async {
    final name = _nameController.text.trim();
    final amountDouble = double.tryParse(_amount) ?? 0;

    if (name.isEmpty) {
      CustomToast.show(context, '请输入联系人姓名', isError: true);
      return;
    }

    if (amountDouble <= 0) {
      CustomToast.show(context, '请输入有效金额', isError: true);
      return;
    }

    // 隐藏键盘
    FocusScope.of(context).unfocus();
    setState(() => _showNumpad = false);

    // 显示确认弹窗
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppTheme.spacingL),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, 
                height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '确认保存记录', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildConfirmationRow('金额', '¥ $_amount', isHighlight: true),
            const Divider(height: 32),
            _buildConfirmationRow('类型', _isReceived ? '收礼' : '送礼'),
            const SizedBox(height: 16),
            _buildConfirmationRow('对象', '$name ($_relationship)'),
            const SizedBox(height: 16),
            _buildConfirmationRow('日期', DateFormat('yyyy-MM-dd').format(_selectedDate)),
            if (_noteController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildConfirmationRow('备注', _noteController.text),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('返回修改', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _executeSave(name, amountDouble);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _isReceived ? AppTheme.primaryColor : AppTheme.accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('确认写入', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSave(String name, double amount) async {
    setState(() => _isSaving = true);
    try {
      // 编辑模式：更新现有记录
      if (widget.editingGift != null) {
        final giftToUpdate = Gift(
          id: widget.editingGift!.id,
          guestId: widget.editingGift!.guestId,
          amount: amount,
          isReceived: _isReceived,
          eventType: _eventType,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

        await _db.updateGift(giftToUpdate);

        // 如果姓名或关系变了，更新 Guest
        if (widget.editingGuest != null) {
          if (widget.editingGuest!.name != name || widget.editingGuest!.relationship != _relationship) {
            final guestToUpdate = Guest(
              id: widget.editingGuest!.id,
              name: name,
              relationship: _relationship,
            );
            await _db.updateGuest(guestToUpdate);
          }
        }

        if (mounted) {
          CustomToast.show(context, '更新成功');
          Navigator.pop(context, true);
        }
      } else {
        // 新增模式：创建新记录
        final guest = Guest(
          name: name,
          relationship: _relationship,
        );
        
        final gift = Gift(
          guestId: 0, 
          amount: amount,
          isReceived: _isReceived,
          eventType: _eventType,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

        await _db.saveGiftWithGuest(gift, guest);
        
        if (mounted) {
          CustomToast.show(context, '保存成功');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '保存失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isReceived ? AppTheme.primaryColor : AppTheme.accentColor;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('新增礼金', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withOpacity(0.08),
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: GestureDetector(
          onTap: () {
            // 点击空白处收起所有键?
            FocusScope.of(context).unfocus();
            setState(() => _showNumpad = false);
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppTheme.spacingL, 100, AppTheme.spacingL, AppTheme.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // 点击金额卡片内容区域（非快捷按钮），先清空金额再显示数字键盘
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _amount = '0';
                            _showNumpad = true;
                          });
                        },
                        child: _buildAmountCard(accentColor),
                      ),
                      const SizedBox(height: 24),
                      _buildNeoSection('记录类型', _buildPremiumTypeSelector(accentColor)),
                      const SizedBox(height: 24),
                      _buildNeoSection('基本信息', _buildInfoSection()),
                      const SizedBox(height: 24),
                      _buildNeoSection('高级选项', _buildAdvancedSection()),
                      const SizedBox(height: 24),
                      // 给底部按钮留出空间，键盘显示时不需?
                      if (!isKeyboardVisible) const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              // 键盘显示时隐藏保存按?
              if (!isKeyboardVisible) _buildStickySaveBar(accentColor),
              
              // 当请求显示且系统键盘未弹出时，显示自定义数字键盘
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: (_showNumpad && !isKeyboardVisible) 
                    ? _buildCustomNumPad()
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickySaveBar(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: _buildPremiumSaveButton(accentColor),
    );
  }

  Widget _buildNeoSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.textSecondary.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildAmountCard(Color accentColor) {
    final quickAmounts = [100, 200, 500, 1000, 2000, 5000, 10000];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            '礼金金额',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: accentColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _amount,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 分割线
          Divider(color: Colors.grey.withOpacity(0.1), height: 1),
          const SizedBox(height: 16),
          // 内部快捷选择器
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: quickAmounts.map((amount) {
                final amountStr = amount.toString();
                final isSelected = _amount == amountStr;
                return GestureDetector(
                  onTap: () {
                     // 阻止冒泡到父GestureDetector (如果有的话，但这里我们已经在内部了)
                    setState(() {
                      _amount = amountStr;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : accentColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      '¥$amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : accentColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPremiumTypeSelector(Color accentColor) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTypeButton('收礼', true, accentColor),
          _buildTypeButton('送礼', false, AppTheme.accentColor),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, bool value, Color color) {
    final isSelected = _isReceived == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isReceived = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isSelected ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildNeoInput(
            controller: _nameController,
            focusNode: _nameFocusNode,
            hint: '联系人姓名',
            icon: Icons.person_rounded,
            layerLink: _nameLayerLink,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: '事由',
                  value: _eventType,
                  icon: Icons.celebration_rounded,
                  onTap: () => _showPicker(
                    context,
                    title: '选择事由',
                    items: EventTypes.all,
                    current: _eventType,
                    onSelect: (v) => setState(() => _eventType = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceChip(
                  label: '关系',
                  value: _relationship,
                  icon: Icons.people_alt_rounded,
                  onTap: () => _showPicker(
                    context,
                    title: '选择关系',
                    items: RelationshipTypes.all,
                    current: _relationship,
                    onSelect: (v) => setState(() => _relationship = v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSaveButton(Color accentColor) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: accentColor.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isSaving 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded),
                SizedBox(width: 12),
                Text('保存记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ],
            ),
        ),
    );
  }

  Widget _buildAdvancedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildChoiceChip(
            label: '日期',
            value: DateFormat('yyyy年MM月dd日', 'zh_CN').format(_selectedDate),
            icon: Icons.calendar_month_rounded,
            onTap: () => _selectDate(context),
            fullWidth: true,
          ),
          const SizedBox(height: 16),
          _buildNeoInput(
            controller: _noteController,
            hint: '添加备注...',
            icon: Icons.edit_note_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildNeoInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    LayerLink? layerLink,
    FocusNode? focusNode,
  }) {
    // 基础输入?
    Widget textField = TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      onTap: () {
        FocusScope.of(context).unfocus(); // 收起键盘
        // 点击输入框时隐藏自定义数字键?
        setState(() => _showNumpad = false);
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );

    // 如果提供?layerLink，则包裹 CompositedTransformTarget
    if (layerLink != null) {
      return CompositedTransformTarget(
        link: layerLink,
        child: textField,
      );
    }

    return textField;
  }

  Widget _buildChoiceChip({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: () {
        // 使用 FocusManager 直接清除主焦点，比 FocusScope 更可靠
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.6), fontWeight: FontWeight.w800)),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppTheme.textSecondary.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String current,
    required Function(String) onSelect,
  }) async {
    // 显示前清除焦点 - 使用 FocusManager 直接操作
    FocusManager.instance.primaryFocus?.unfocus();
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((item) {
                  final isSelected = item == current;
                  return GestureDetector(
                    onTap: () {
                      onSelect(item);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected ? [
                          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                        ] : null,
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
    
    // 弹窗关闭后，再次确保取消焦点，防止键盘弹出
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _buildCustomNumPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: CustomNumpad(
        onDigitPressed: _onDigitPressed,
        onDelete: _onDelete,
        onDone: _saveRecord,
      ),
    );
  }
}
