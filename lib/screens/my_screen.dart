import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/api_providers.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/export_dialogs.dart';
import 'about_app_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'template_settings_screen.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '我的',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '账户、同步与常用功能',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildGithubHeaderAction(
                      onTap: () => launchUrl(
                        Uri.parse('https://github.com/final00000000/Gift_Ledger'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderAction(
                      context: context,
                      icon: Icons.settings_rounded,
                      tooltip: '设置',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHero(
                      context: context,
                      authState: authState,
                      syncState: syncState,
                      onLoginTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      onSyncTap: () async {
                        await ref.read(syncProvider.notifier).syncAll();
                        if (!context.mounted) return;
                        final message = ref.read(syncProvider).message ?? '同步已完成';
                        CustomToast.show(context, message);
                      },
                      onLogoutTap: () async {
                        await ref.read(authStateProvider.notifier).logout();
                        if (!context.mounted) return;
                        CustomToast.show(context, '已退出登录');
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('常用功能'),
                    _buildSectionCard(
                      children: [
                        _buildNavigationTile(
                          icon: Icons.file_upload_outlined,
                          iconColor: Colors.teal,
                          title: '导出数据',
                          subtitle: '备份数据到本地或分享给他人',
                          onTap: () => ExportDialogs.showExportOptions(context),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildNavigationTile(
                          icon: Icons.file_download_outlined,
                          iconColor: Colors.indigo,
                          title: '导入数据',
                          subtitle: '恢复备份或从 Excel 导入',
                          onTap: () => ExportDialogs.showImportOptions(context, () {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('数据导入成功，请返回首页查看')),
                              );
                            }
                          }),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('应用与支持'),
                    _buildSectionCard(
                      children: [
                        _buildNavigationTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: AppTheme.primaryColor,
                          title: '关于应用',
                          subtitle: '版本信息、更新与项目说明',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutAppScreen(currentVersion: ''),
                            ),
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

  Widget _buildGithubHeaderAction({
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'GitHub',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF24292F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const FaIcon(FontAwesomeIcons.github, size: 18),
    );
  }

  Widget _buildHeaderAction({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon),
    );
  }

  Widget _buildProfileHero({
    required BuildContext context,
    required AuthState authState,
    required SyncState syncState,
    required VoidCallback onLoginTap,
    required VoidCallback onSyncTap,
    required VoidCallback onLogoutTap,
  }) {
    final isAuthenticated = authState.isAuthenticated;
    final displayName = authState.fullName?.trim().isNotEmpty == true
        ? authState.fullName!.trim()
        : '已登录用户';
    final title = isAuthenticated ? displayName : '立即登录';
    final subtitle = isAuthenticated
        ? (authState.email?.trim().isNotEmpty == true
            ? authState.email!.trim()
            : '已连接云同步能力')
        : '登录后可同步账本与备份数据，本地数据仍可正常使用';
    final initial = title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '访';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.96),
            const Color(0xFFB73A3A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isAuthenticated ? '已登录 · 云同步可用' : '未登录 · 本地数据可用',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroStat(
                    label: '同步状态',
                    value: _syncStatusLabel(syncState),
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _buildHeroStat(
                    label: '最近状态',
                    value: syncState.lastSyncAt == null ? '未同步' : '已同步',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isAuthenticated ? onSyncTap : onLoginTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(isAuthenticated ? '同步数据' : '登录 / 注册'),
                ),
              ),
              if (isAuthenticated) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onLogoutTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('退出'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary.withValues(alpha: 0.78),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(children: children),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  String _syncStatusLabel(SyncState state) {
    switch (state.status) {
      case SyncStatus.syncing:
        return '同步中';
      case SyncStatus.success:
        return '同步成功';
      case SyncStatus.error:
        return '同步失败';
      case SyncStatus.idle:
        return '待同步';
    }
  }
}
