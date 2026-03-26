import '../../models/update_target.dart';

export 'update_installer_stub.dart'
    if (dart.library.io) 'update_installer_io.dart' show createUpdateInstaller;

typedef DownloadProgressCallback = void Function(DownloadProgress progress);

class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  bool get hasTotalBytes => totalBytes > 0;

  double? get fraction {
    if (!hasTotalBytes) {
      return null;
    }

    final normalizedReceived = receivedBytes.clamp(0, totalBytes);
    return normalizedReceived / totalBytes;
  }
}

class InstallResult {
  final bool didOpen;
  final String savePath;
  final String message;

  const InstallResult({
    required this.didOpen,
    required this.savePath,
    required this.message,
  });
}

class UpdateInstallerException implements Exception {
  final String message;

  const UpdateInstallerException(this.message);

  @override
  String toString() {
    return 'UpdateInstallerException: $message';
  }
}

abstract class UpdateInstaller {
  Future<bool> canInstallPackages();

  Future<bool> requestInstallPermission();

  Future<InstallResult> downloadAndOpen(
    UpdateTarget target, {
    DownloadProgressCallback? onProgress,
  });

  Future<InstallResult> reopenDownloadedPackage(String filePath);
}
