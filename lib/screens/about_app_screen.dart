import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/update_target.dart';
import '../services/update/update_controller.dart';
import '../services/update/update_prompt_policy.dart';
import '../services/update/update_ui_coordinator.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/update/update_channel_section.dart';
import '../widgets/update/update_release_notes_section.dart';
import '../widgets/update/update_settings_section.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({
    super.key,
    required this.currentVersion,
  });

  final String currentVersion;

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  static final Uri _githubUri =
      Uri.parse('https://github.com/final00000000/Gift_Ledger');

  String get _versionLabel {
    return widget.currentVersion.trim().isEmpty
        ? '当前版本未知'
        : '当前版本 v${widget.currentVersion}';
  }

  Future<void> _handleManualUpdateCheck(UpdateController controller) async {
    await controller.checkForUpdates(source: UpdateCheckSource.manual);
    final state = controller.state;

    if (state.status == UpdateStateStatus.error) {
      if (mounted) {
        CustomToast.show(context, '当前网络不可用，或暂时无法访问更新服务');
      }
      return;
    }

    if (state.target != null) {
      scheduleManualUpdatePresentation(
        controller: controller,
        target: state.target!,
        isMounted: () => mounted,
        schedulePostFrame: WidgetsBinding.instance.addPostFrameCallback,
        showMessage: (message) {
          CustomToast.show(context, message);
        },
      );
      return;
    }

    if (!mounted) {
      return;
    }

    if (state.status == UpdateStateStatus.upToDate) {
      CustomToast.show(context, '当前已是最新版本');
    }
  }

  Future<void> _handleInstallCurrentUpdate(UpdateController controller) async {
    final message = await installCurrentUpdateAndCollectMessage(controller);
    if (!mounted || message == null || message.isEmpty) {
      return;
    }

    CustomToast.show(context, message);
  }

  void _handleUpdateChannelChanged(UpdateController controller, bool enabled) {
    controller.setSelectedChannel(
      enabled ? UpdateChannel.beta : UpdateChannel.stable,
    );
    if (!mounted) {
      return;
    }

    CustomToast.show(context, enabled ? '已切换到 Beta 通道' : '已切换到稳定通道');
  }

  Future<void> _openGithub() async {
    await launchUrl(
      _githubUri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateController = context.watch<UpdateController>();
    final updateState = updateController.state;
    final updateTarget = updateState.target;
    final updateBusy = updateState.status == UpdateStateStatus.checking ||
        updateState.status == UpdateStateStatus.installing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('关于随礼记'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AboutHeader(versionLabel: _versionLabel),
          const SizedBox(height: 16),
          UpdateSettingsSection(
            currentVersion: widget.currentVersion,
            status: updateState.status,
            lastSource: updateState.lastSource,
            target: updateTarget,
            onCheckPressed: () => _handleManualUpdateCheck(updateController),
            onInstallPressed: () =>
                _handleInstallCurrentUpdate(updateController),
          ),
          const SizedBox(height: 12),
          UpdateChannelSection(
            selectedChannel: updateController.selectedChannel,
            enabled: !updateBusy,
            onBetaChanged: (enabled) {
              _handleUpdateChannelChanged(updateController, enabled);
            },
          ),
          if (updateTarget?.notes.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            UpdateReleaseNotesSection(notes: updateTarget!.notes),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.github,
                    size: 18,
                    color: Color(0xFF24292F),
                  ),
                  title: const Text(
                    'GitHub',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '查看项目仓库与发布说明',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onTap: _openGithub,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                const Divider(height: 1, indent: 52),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: const Text(
                    '版本信息',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _versionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({
    required this.versionLabel,
  });

  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.14),
                  AppTheme.primaryColor.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '随礼记',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  versionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
