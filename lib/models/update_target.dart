enum UpdateChannel {
  stable,
  beta,
}

enum UpdatePlatform {
  android,
  windows,
}

class UpdateTarget {
  final UpdateChannel channel;
  final UpdateChannel? resolvedTargetChannel;
  final UpdatePlatform platform;
  final String? version;
  final int? buildNumber;
  final String? packageType;
  final String? downloadUrl;
  final String? sha256;
  final String notes;

  const UpdateTarget({
    required this.channel,
    this.resolvedTargetChannel,
    required this.platform,
    this.version,
    this.buildNumber,
    this.packageType,
    this.downloadUrl,
    this.sha256,
    this.notes = '',
  });

  UpdateChannel get effectiveResolvedTargetChannel {
    return resolvedTargetChannel ?? channel;
  }
}
