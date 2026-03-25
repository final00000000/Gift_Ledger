import 'update_target.dart';

class UpdateManifest {
  final int? schemaVersion;
  final String? generatedAt;
  final UpdateChannelManifest stable;
  final UpdateChannelManifest beta;

  const UpdateManifest({
    required this.stable,
    required this.beta,
    this.schemaVersion,
    this.generatedAt,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final channelsJson = _readChannelsJson(json);

    return UpdateManifest(
      schemaVersion: _readSchemaVersion(json['schemaVersion']),
      generatedAt: _readGeneratedAt(json['generatedAt']),
      stable: UpdateChannelManifest.fromJson(
        _requireJsonMap(channelsJson['stable'], 'channels.stable'),
        channel: 'stable',
      ),
      beta: UpdateChannelManifest.fromJson(
        _requireJsonMap(channelsJson['beta'], 'channels.beta'),
        channel: 'beta',
      ),
    );
  }

  Map<UpdateChannel, UpdateChannelManifest> get channels {
    return {
      UpdateChannel.stable: stable,
      UpdateChannel.beta: beta,
    };
  }

  UpdateChannelManifest getChannel(UpdateChannel channel) {
    switch (channel) {
      case UpdateChannel.stable:
        return stable;
      case UpdateChannel.beta:
        return beta;
    }
  }

  UpdateManifestEntry? getEntry(UpdateTarget target) {
    return getChannel(target.effectiveResolvedTargetChannel)
        .getEntry(target.platform);
  }

  static Map<String, dynamic> _readChannelsJson(Map<String, dynamic> json) {
    final channels = json['channels'];
    if (channels != null) {
      return _requireJsonMap(channels, 'channels');
    }

    return {
      'stable': json['stable'],
      'beta': json['beta'],
    };
  }

  static int? _readSchemaVersion(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw const FormatException(
      'Invalid update manifest: "schemaVersion" must be an integer.',
    );
  }

  static String? _readGeneratedAt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw const FormatException(
          'Invalid update manifest: "generatedAt" must be a non-empty string.',
        );
      }
      return trimmed;
    }
    throw const FormatException(
      'Invalid update manifest: "generatedAt" must be a string.',
    );
  }

  static Map<String, dynamic> _requireJsonMap(dynamic value, String path) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw FormatException(
      'Invalid update manifest: "$path" must be an object.',
    );
  }
}

class UpdateChannelManifest {
  final UpdateManifestEntry? android;
  final UpdateManifestEntry? windows;

  const UpdateChannelManifest({
    this.android,
    this.windows,
  });

  factory UpdateChannelManifest.fromJson(
    Map<String, dynamic> json, {
    required String channel,
  }) {
    return UpdateChannelManifest(
      android: UpdateManifestEntry.maybeFromJson(
        json['android'],
        path: '$channel.android',
      ),
      windows: UpdateManifestEntry.maybeFromJson(
        json['windows'],
        path: '$channel.windows',
      ),
    );
  }

  UpdateManifestEntry? getEntry(UpdatePlatform platform) {
    switch (platform) {
      case UpdatePlatform.android:
        return android;
      case UpdatePlatform.windows:
        return windows;
    }
  }
}

class UpdateManifestEntry {
  static const Set<String> _allowedPackageTypes = <String>{
    'apk',
    'exe',
    'msix',
  };

  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String sha256;
  final String packageType;
  final String notes;

  const UpdateManifestEntry({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.sha256,
    required this.packageType,
    required this.notes,
  });

  factory UpdateManifestEntry.fromJson(
    Map<String, dynamic> json, {
    required String path,
  }) {
    return UpdateManifestEntry(
      version: _requireNonEmptyString(
        json['version'],
        fieldName: 'version',
        path: path,
      ),
      buildNumber: _requireBuildNumber(
        json['buildNumber'],
        path: path,
      ),
      downloadUrl: _requireDownloadUrl(
        json['downloadUrl'],
        path: path,
      ),
      sha256: _requireSha256(
        json['sha256'],
        path: path,
      ),
      packageType: _requirePackageType(
        json['packageType'],
        path: path,
      ),
      notes: _readNotes(
        json['notes'],
        path: path,
      ),
    );
  }

  static UpdateManifestEntry? maybeFromJson(
    dynamic json, {
    required String path,
  }) {
    if (json == null) {
      return null;
    }

    if (json is Map) {
      return UpdateManifestEntry.fromJson(
        Map<String, dynamic>.from(json),
        path: path,
      );
    }

    throw FormatException(
      'Invalid update manifest entry: "$path" must be an object.',
    );
  }

  static String _requireNonEmptyString(
    dynamic value, {
    required String fieldName,
    required String path,
  }) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    throw FormatException(
      'Invalid update manifest entry: "$path.$fieldName" must be a non-empty string.',
    );
  }

  static int _requireBuildNumber(
    dynamic value, {
    required String path,
  }) {
    if (value is int) {
      return value;
    }

    throw FormatException(
      'Invalid update manifest entry: "$path.buildNumber" must be an integer.',
    );
  }

  static String _requireDownloadUrl(
    dynamic value, {
    required String path,
  }) {
    final url = _requireNonEmptyString(
      value,
      fieldName: 'downloadUrl',
      path: path,
    );
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return url;
    }

    throw FormatException(
      'Invalid update manifest entry: "$path.downloadUrl" must be an absolute URL.',
    );
  }

  static String _requireSha256(
    dynamic value, {
    required String path,
  }) {
    final sha256 = _requireNonEmptyString(
      value,
      fieldName: 'sha256',
      path: path,
    );
    final pattern = RegExp(r'^[0-9a-fA-F]{64}$');
    if (pattern.hasMatch(sha256)) {
      return sha256.toLowerCase();
    }

    throw FormatException(
      'Invalid update manifest entry: "$path.sha256" must be a 64-character hex string.',
    );
  }

  static String _requirePackageType(
    dynamic value, {
    required String path,
  }) {
    final packageType = _requireNonEmptyString(
      value,
      fieldName: 'packageType',
      path: path,
    ).toLowerCase();
    if (_allowedPackageTypes.contains(packageType)) {
      return packageType;
    }

    throw FormatException(
      'Invalid update manifest entry: "$path.packageType" must be one of: apk, exe, msix.',
    );
  }

  static String _readNotes(
    dynamic value, {
    required String path,
  }) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      return value.trim();
    }

    throw FormatException(
      'Invalid update manifest entry: "$path.notes" must be a string.',
    );
  }
}
