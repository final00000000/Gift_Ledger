import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/export_dialogs.dart';
import '../services/template_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
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
  bool _showHomeAmounts = true;
  final TemplateService _templateService = TemplateService();
  final NotificationService _notificationService = NotificationService();
  final StorageService _db = StorageService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // 并行加载所有设置
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      _templateService.getUseFuzzyAmount(),
      _notificationService.isEnabled(),
      _db.getStatsIncludeEventBooks(),
      _db.getEventBooksEnabled(),
      _db.getShowHomeAmounts(),
    ]);
    
    final prefs = results[0] as SharedPreferences;
    setState(() {
      _defaultIsReceived = prefs.getBool('default_is_received') ?? true;
      _useFuzzyAmount = results[1] as bool;
      _notificationsEnabled = results[2] as bool;
      _statsIncludeEventBooks = results[3] as bool;
      _eventBooksEnabled = results[4] as bool;
      _showHomeAmounts = results[5] as bool;
    });
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

  /// 公开刷新方法，供控制器调用
  void refreshData() {
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80.0,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                '设置',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        icon: Icons.visibility_rounded,
                        iconColor: Colors.blueGrey,
                        title: '显示首页金额',
                        subtitle: '关闭后首页金额显示为***',
                        value: _showHomeAmounts,
                        onChanged: (v) async {
                          await _db.setShowHomeAmounts(v);
                          setState(() => _showHomeAmounts = v);
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
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                        ),
                        title: const Text('随礼记', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Text('v1.2.0', style: TextStyle(color: AppTheme.textSecondary)),
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
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
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
                color: AppTheme.textSecondary.withOpacity(0.7),
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
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
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
          color: iconColor.withOpacity(0.1),
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
