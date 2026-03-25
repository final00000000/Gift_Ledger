import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/update_target.dart';

class AppBuildInfo {
  final String version;
  final int buildNumber;
  final UpdatePlatform platform;

  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
  });
}

class AppBuildInfoService {
  const AppBuildInfoService();

  Future<AppBuildInfo> getCurrentBuildInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final buildNumber = int.tryParse(packageInfo.buildNumber);
    if (buildNumber == null) {
      throw FormatException(
        'Invalid app build number: ${packageInfo.buildNumber}',
      );
    }

    return AppBuildInfo(
      version: packageInfo.version,
      buildNumber: buildNumber,
      platform: _resolvePlatform(),
    );
  }

  UpdatePlatform _resolvePlatform() {
    if (kIsWeb) {
      throw UnsupportedError('App updates are not supported on web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return UpdatePlatform.android;
      case TargetPlatform.windows:
        return UpdatePlatform.windows;
      default:
        throw UnsupportedError(
          'App updates are only supported on Android and Windows.',
        );
    }
  }
}
