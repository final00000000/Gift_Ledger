import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/update_manifest.dart';
import '../../models/update_target.dart';

class AppBuildInfo {
  final String version;
  final int buildNumber;
  final UpdatePlatform platform;
  final String? androidAbi;

  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
    this.androidAbi,
  });
}

class AppBuildInfoService {
  static const MethodChannel _appInfoChannel = MethodChannel(
    'com.giftmoney.gift_ledger/app_info',
  );

  const AppBuildInfoService();

  Future<AppBuildInfo> getCurrentBuildInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version.trim().isEmpty ? '0.0.0' : packageInfo.version.trim();
    final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    final platform = _resolvePlatform();
    final androidAbi = platform == UpdatePlatform.android
        ? await _resolveAndroidAbi()
        : null;

    return AppBuildInfo(
      version: version,
      buildNumber: buildNumber,
      platform: platform,
      androidAbi: androidAbi,
    );
  }

  Future<String?> _resolveAndroidAbi() async {
    try {
      final abi = await _appInfoChannel.invokeMethod<String>('getPreferredAbi');
      return UpdateManifestEntry.normalizeAndroidAbi(abi);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
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
        return UpdatePlatform.android; // iOS 等平台暂不支持自动更新，返回占位值
    }
  }
}
