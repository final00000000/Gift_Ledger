import '../../models/update_target.dart';

export 'update_installer_stub.dart'
    if (dart.library.io) 'update_installer_io.dart' show createUpdateInstaller;

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
  Future<InstallResult> downloadAndOpen(UpdateTarget target);
}
