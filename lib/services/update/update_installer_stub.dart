import 'package:dio/dio.dart';

import '../../models/update_target.dart';
import 'update_installer.dart';

UpdateInstaller createUpdateInstaller({Dio? dio}) {
  return const StubUpdateInstaller();
}

class StubUpdateInstaller implements UpdateInstaller {
  const StubUpdateInstaller();

  @override
  Future<InstallResult> downloadAndOpen(UpdateTarget target) {
    throw const UpdateInstallerException(
      'Update installation is not supported on this platform.',
    );
  }
}
