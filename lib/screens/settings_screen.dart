import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/export_dialogs.dart';
import '../services/template_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/security_service.dart';
import '../widgets/pin_code_dialog.dart';
import 'template_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _defaultIsReceived = true;
  bool _useFuzzyAmount = false;
  bool _notificationsEnabled = false;
  bool _statsIncludeEventBooks = true;
  bool _eventBooksEnabled = true;
  String _securityMode = SecurityService.modeNone;
  bool _isLoading = true; // 添加加载状态
  String _appVersion = '';
  final TemplateService _templateService = TemplateService();
  final NotificationService _notificationService = NotificationService();
  final StorageService _db = StorageService();
  final SecurityService _securityService = SecurityService();

  @override
  void initState() {
    super.initState();
    // 监听 StorageService 变化，自动刷新设置
    _db.addListener(_onDataChanged);
    _loadAppInfo();
    _loadSettings();
  }

  /// StorageService 数据变化时的回调
  void _onDataChanged() {
    if (mounted) {
      _loadSettings();
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      final text = await rootBundle.loadString('pubspec.yaml');
      final match = RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(text);
      final raw = match?.group(1) ?? '';
      final semver = raw.split('+').first;
      if (!mounted) return;
      setState(() {
        _appVersion = semver;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appVersion = '';
      });
    }
  }

  @override
  void dispose() {
    _db.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // 并行加载所有设置
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      _templateService.getUseFuzzyAmount(),
      _notificationService.isEnabled(),
      _db.getStatsIncludeEventBooks(),
      _db.getEventBooksEnabled(),
      _securityService.getSecurityMode(),
    ]);

    final prefs = results[0] as SharedPreferences;
    if (mounted) {
      setState(() {
        _defaultIsReceived = prefs.getBool('default_is_received') ?? true;
        _useFuzzyAmount = results[1] as bool;
        _notificationsEnabled = results[2] as bool;
        _statsIncludeEventBooks = results[3] as bool;
        _eventBooksEnabled = results[4] as bool;
        _securityMode = results[5] as String;
        _isLoading = false; // 标记加载完成
      });
    }
  }

  Future<void> _saveSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('default_is_received', value);
    setState(() {
      _defaultIsReceived = value;
    });
    if (mounted) {
      CustomToast.show(context, '设置已保存');
    }
  }

  Future<void> _handleSecurityModeChange(String mode) async {
    if (mode == _securityMode) return;

    // 关键修复：如果当前已经有锁（不是无锁模式），修改设置前必须验证密码
    // 无论是关闭锁、还是切换模式，都需要验证
    if (_securityMode != SecurityService.modeNone) {
      if (!mounted) return;
      // 弹出验证框
      final verified = await PinCodeDialog.show(context);
      if (!verified) return; // 验证失败，终止修改
    }

    // 如果要开启安全模式，必须先检查是否有密码
    if (mode != SecurityService.modeNone) {
      final hasPin = await _securityService.hasPin();
      if (!hasPin) {
        if (!mounted) return;
        final pinSet = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PinCodeDialog(
            isSettingPin: true,
            onPinSet: (pin) => _securityService.setPin(pin),
          ),
        );
        
        if (pinSet != true) return; // 用户取消设置密码
      } else {
        // 如果已经有密码，且是从无锁切到有锁，这里不需要额外验证
        // (因为上面已经验证了从有锁切过来的情况；如果是无锁切有锁，只要有密码就行，或者强制验证一次也无妨，保持逻辑简单)
      }
    }

    await _securityService.setSecurityMode(mode);
    setState(() => _securityMode = mode);
    
    // 隐形模式下，自动关闭"显示首页金额"
    if (mode == SecurityService.modeInvisible) {
       // 更新数据库设置（逻辑上已经由SecurityService控制）
       await _db.setShowHomeAmounts(false);
    }
  }

  Future<void> _changePassword() async {
    // 先验证旧密码
    final verified = await PinCodeDialog.show(context);
    if (!verified) return;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PinCodeDialog(
        isSettingPin: true,
        title: '设置新密码',
        onPinSet: (pin) async {
           await _securityService.setPin(pin);
           if (mounted) CustomToast.show(context, '密码修改成功');
        },
      ),
    );
  }

  /// 公开刷新方法，供控制器调用
  void refreshData() {
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 简化的头部
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '设置',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // 安全与隐私
                    _buildSectionCard(
                      title: '安全与隐私',
                      children: [
                        _buildNavigationTile(
                          icon: Icons.security_rounded,
                          iconColor: _securityMode == SecurityService.modeNone
                              ? Colors.grey
                              : (_securityMode == SecurityService.modeInvisible ? AppTheme.primaryColor : Colors.orange),
                          title: '应用安全锁',
                          subtitle: _getSecurityModeText(_securityMode),
                          onTap: () => _showSecurityModePicker(),
                        ),
                        if (_securityMode != SecurityService.modeNone) ...[
                          const Divider(height: 1, indent: 52),
                          _buildNavigationTile(
                            icon: Icons.password_rounded,
                            iconColor: AppTheme.textPrimary,
                            title: '修改安全密码',
                            subtitle: '重置您的6位PIN码',
                            onTap: _changePassword,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 记账与统计
                    _buildSectionCard(
                      title: '记账与统计',
                      children: [
                        _buildSwitchTile(
                          icon: Icons.auto_awesome_rounded,
                          iconColor: AppTheme.primaryColor,
                          title: '默认收礼模式',
                          subtitle: '新建记录时默认选中收礼',
                          value: _defaultIsReceived,
                          onChanged: (v) => _saveSetting(v),
                        ),
                        const Divider(height: 1, indent: 52),
                        _buildSwitchTile(
                          icon: Icons.pie_chart_rounded,
                          iconColor: Colors.purple,
                          title: '统计包含活动簿',
                          subtitle: '首页统计是否包含活动簿内的礼金',
                          value: _statsIncludeEventBooks,
                          onChanged: (v) async {
                            await _db.setStatsIncludeEventBooks(v);
                            setState(() => _statsIncludeEventBooks = v);
                            if (mounted) CustomToast.show(context, '设置已保存');
                          },
                        ),
                        const Divider(height: 1, indent: 52),
                        _buildSwitchTile(
                          icon: Icons.book_outlined,
                          iconColor: Colors.deepPurple,
                          title: '启用活动簿',
                          subtitle: '关闭后首页不显示活动簿入口',
                          value: _eventBooksEnabled,
                          onChanged: (v) async {
                            await _db.setEventBooksEnabled(v);
                            setState(() => _eventBooksEnabled = v);
                            if (mounted) CustomToast.show(context, '设置已保存');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 还礼提醒
                    _buildSectionCard(
                      title: '还礼提醒',
                      children: [
                        _buildSwitchTile(
                          icon: Icons.blur_on_rounded,
                          iconColor: AppTheme.primaryColor,
                          title: '模糊金额',
                          subtitle: '提醒话术中将金额显示为"千把块"等',
                          value: _useFuzzyAmount,
                          onChanged: (v) async {
                            await _templateService.setUseFuzzyAmount(v);
                            setState(() => _useFuzzyAmount = v);
                            if (mounted) CustomToast.show(context, '设置已保存');
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildNavigationTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: AppTheme.primaryColor,
                          title: '话术模板',
                          subtitle: '自定义提醒消息模板',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TemplateSettingsScreen()),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildSwitchTile(
                          icon: Icons.notifications_active_rounded,
                          iconColor: AppTheme.primaryColor,
                          title: '每月提醒',
                          subtitle: '每月初推送待还人情Top3',
                          value: _notificationsEnabled,
                          onChanged: (v) async {
                            await _notificationService.setEnabled(v);
                            setState(() => _notificationsEnabled = v);
                            if (mounted) CustomToast.show(context, v ? '已开启每月提醒' : '已关闭每月提醒');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 数据管理
                    _buildSectionCard(
                      title: '数据管理',
                      children: [
                        _buildNavigationTile(
                          icon: Icons.file_upload_outlined,
                          iconColor: AppTheme.primaryColor,
                          title: '导出数据',
                          subtitle: '备份数据到本地或分享',
                          onTap: () => ExportDialogs.showExportOptions(context),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildNavigationTile(
                          icon: Icons.file_download_outlined,
                          iconColor: AppTheme.primaryColor,
                          title: '导入数据',
                          subtitle: '恢复备份或从 Excel 导入',
                          onTap: () => ExportDialogs.showImportOptions(context, () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('数据导入成功，请下拉刷新首页查看')),
                              );
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 关于
                    _buildSectionCard(
                      title: '关于',
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                          ),
                          title: const Text('随礼记', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(
                            _appVersion.isEmpty ? 'v--' : 'v$_appVersion',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSecurityModeText(String mode) {
    switch (mode) {
      case SecurityService.modeInvisible:
        return '隐形防护 (推荐): 仅隐藏金额';
      case SecurityService.modeFortress:
        return '堡垒模式: 启动时锁定';
      default:
        return '已关闭';
    }
  }

  void _showSecurityModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('选择安全模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            _buildModeOption(
              mode: SecurityService.modeNone,
              title: '关闭 (无锁)',
              subtitle: '进入应用无需密码，金额直接显示',
              icon: Icons.lock_open_rounded,
              color: Colors.grey,
            ),
            _buildModeOption(
              mode: SecurityService.modeInvisible,
              title: '隐形防护 (推荐)',
              subtitle: '秒开应用。金额默认隐藏，查看详情或编辑时验证',
              icon: Icons.visibility_off_rounded,
              color: AppTheme.primaryColor,
            ),
            _buildModeOption(
              mode: SecurityService.modeFortress,
              title: '堡垒模式',
              subtitle: '每次打开应用或从后台切回时强制验证',
              icon: Icons.lock_rounded,
              color: Colors.orange,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _securityMode == mode;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _handleSecurityModeChange(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? color.withValues(alpha: 0.05) : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? color : AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppTheme.primaryColor,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
