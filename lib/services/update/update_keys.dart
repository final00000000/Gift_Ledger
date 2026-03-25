import '../../models/update_target.dart';

const String updateManifestCacheKey = 'update.manifest.json';
const String promptedTargetKeysConfigKey = 'update.promptedTargetKeys';
const String ignoredTargetKeysConfigKey = 'update.ignoredTargetKeys';
const String selectedUpdateChannelConfigKey = 'update.selectedChannel';

String buildSafeUpdateTargetKey(UpdateTarget target) {
  final version = target.version ?? 'unknown';
  final buildNumber = target.buildNumber?.toString() ?? 'unknown';

  return '${target.effectiveResolvedTargetChannel.name}'
      '@${target.platform.name}'
      '@$version'
      '@$buildNumber';
}

String buildUpdateTargetKey(UpdateTarget target) {
  final version = target.version;
  final buildNumber = target.buildNumber;

  if (version == null || buildNumber == null) {
    throw StateError(
      'Cannot build update target key without version and buildNumber.',
    );
  }

  return buildSafeUpdateTargetKey(target);
}
