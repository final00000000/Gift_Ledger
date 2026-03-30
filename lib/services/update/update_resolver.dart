import '../../models/update_manifest.dart';
import '../../models/update_target.dart';
import '../../utils/semver_utils.dart';

class UpdateResolver {
  const UpdateResolver();

  UpdateTarget? resolve({
    required UpdateManifest manifest,
    required UpdateChannel selectedChannel,
    required UpdatePlatform platform,
    required String currentVersion,
    int? currentBuildNumber,
    String? currentAbi,
  }) {
    switch (selectedChannel) {
      case UpdateChannel.stable:
        return _resolveTarget(
          entry: manifest.stable.getEntry(platform),
          selectedChannel: selectedChannel,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: platform,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          currentAbi: currentAbi,
        );
      case UpdateChannel.beta:
        final betaTarget = _resolveTarget(
          entry: manifest.beta.getEntry(platform),
          selectedChannel: selectedChannel,
          resolvedTargetChannel: UpdateChannel.beta,
          platform: platform,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          currentAbi: currentAbi,
        );
        if (betaTarget != null) {
          return betaTarget;
        }

        return _resolveTarget(
          entry: manifest.stable.getEntry(platform),
          selectedChannel: selectedChannel,
          resolvedTargetChannel: UpdateChannel.stable,
          platform: platform,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          currentAbi: currentAbi,
        );
    }
  }

  UpdateTarget? _resolveTarget({
    required UpdateManifestEntry? entry,
    required UpdateChannel selectedChannel,
    required UpdateChannel resolvedTargetChannel,
    required UpdatePlatform platform,
    required String currentVersion,
    required int? currentBuildNumber,
    String? currentAbi,
  }) {
    if (!_isHigherThanCurrent(
      entry,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
    )) {
      return null;
    }

    return UpdateTarget(
      channel: selectedChannel,
      resolvedTargetChannel: resolvedTargetChannel,
      platform: platform,
      abi: platform == UpdatePlatform.android
          ? entry!.resolveAbi(preferredAbi: currentAbi)
          : null,
      version: entry!.version,
      buildNumber: entry.buildNumber,
      packageType: entry.resolvePackageType(preferredAbi: currentAbi),
      downloadUrl: entry.resolveDownloadUrl(preferredAbi: currentAbi),
      sha256: entry.resolveSha256(preferredAbi: currentAbi),
      notes: entry.notes,
    );
  }

  bool _isHigherThanCurrent(
    UpdateManifestEntry? entry, {
    required String currentVersion,
    required int? currentBuildNumber,
  }) {
    if (entry == null) {
      return false;
    }

    final versionComparison = compareSemver(entry.version, currentVersion);
    if (versionComparison > 0) {
      return true;
    }
    if (versionComparison < 0) {
      return false;
    }

    if (currentBuildNumber == null) {
      return false;
    }

    return entry.buildNumber > currentBuildNumber;
  }
}
