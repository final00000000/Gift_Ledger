import 'package:dio/dio.dart';

import '../../models/update_target.dart';
import 'update_installer.dart';

UpdateInstaller createUpdateInstaller({Dio? dio}) {
  return const StubUpdateInstaller();
}

class StubUpdateInstaller implements UpdateInstaller {
  const StubUpdateInstaller();

  @override
  Future<bool> canInstallPackages() async {
    return true;
  }

  @override
  Future<bool> requestInstallPermission() async {
    return true;
  }

  @override
  Future<InstallResult> downloadAndOpen(
    UpdateTarget target, {
    DownloadProgressCallback? onProgress,
  }) async {
    throw const UpdateInstallerException(
      'Update installation is not supported on this platform.',
    );
  }

  @override
  Future<InstallResult> reopenDownloadedPackage(String filePath) async {
    throw const UpdateInstallerException(
      'Update installation is not supported on this platform.',
    );
  }
}
