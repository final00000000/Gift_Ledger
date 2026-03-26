import '../../models/update_target.dart';
import 'update_keys.dart';

enum UpdateCheckSource {
  startup,
  manual,
}

class UpdatePromptDecision {
  final bool showDialog;
  final bool showRedDot;
  final bool showBanner;

  const UpdatePromptDecision({
    required this.showDialog,
    required this.showRedDot,
    required this.showBanner,
  });
}

class UpdatePromptPolicy {
  const UpdatePromptPolicy();

  UpdatePromptDecision decide({
    required UpdateCheckSource source,
    required UpdateTarget target,
    required Set<String> ignoredTargetKeys,
    required Set<String> promptedTargetKeys,
  }) {
    final targetKey = buildUpdateTargetKey(target);
    final isIgnored = ignoredTargetKeys.contains(targetKey);

    if (isIgnored) {
      return const UpdatePromptDecision(
        showDialog: false,
        showRedDot: true,
        showBanner: false,
      );
    }

    if (source == UpdateCheckSource.startup) {
      return const UpdatePromptDecision(
        showDialog: true,
        showRedDot: true,
        showBanner: false,
      );
    }

    return const UpdatePromptDecision(
      showDialog: false,
      showRedDot: true,
      showBanner: false,
    );
  }
}
