import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/update_target.dart';
import 'update_installer.dart';

typedef DownloadDirectoryProvider = Future<Directory> Function();

UpdateInstaller createUpdateInstaller({
  Dio? dio,
  DownloadDirectoryProvider? directoryProvider,
}) {
  return IoUpdateInstaller(
    dio: dio,
    directoryProvider: directoryProvider,
  );
}

class IoUpdateInstaller implements UpdateInstaller {
  IoUpdateInstaller({
    Dio? dio,
    DownloadDirectoryProvider? directoryProvider,
  })  : _dio = dio ?? Dio(),
        _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  final Dio _dio;
  final DownloadDirectoryProvider _directoryProvider;

  @override
  Future<InstallResult> downloadAndOpen(UpdateTarget target) async {
    final downloadUrl = target.downloadUrl;
    final sha256 = target.sha256;
    final version = target.version;
    final packageType = target.packageType;

    if (downloadUrl == null ||
        sha256 == null ||
        version == null ||
        packageType == null) {
      throw const UpdateInstallerException(
        'Cannot install update without downloadUrl, sha256, version and packageType.',
      );
    }

    final directory = await _directoryProvider();
    final savePath = _joinPath(
      directory.path,
      _buildFileName(version: version, packageType: packageType),
    );

    await _dio.download(downloadUrl, savePath);

    final actualSha256 = await _computeSha256(savePath);
    if (actualSha256 != sha256.toLowerCase()) {
      await _deleteIfExists(savePath);
      throw UpdateInstallerException(
        'SHA-256 mismatch for update package: expected $sha256, got $actualSha256.',
      );
    }

    final openResult = await OpenFilex.open(savePath);
    if (openResult.type != ResultType.done) {
      throw UpdateInstallerException(
        'Failed to open installer: ${openResult.message}',
      );
    }

    return InstallResult(
      didOpen: true,
      savePath: savePath,
      message: openResult.message,
    );
  }

  Future<String> _computeSha256(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return crypto.sha256.convert(bytes).toString();
  }

  Future<void> _deleteIfExists(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {
      // 删除失败不影响主错误语义，这里静默吞掉即可。
    }
  }

  String _buildFileName({
    required String version,
    required String packageType,
  }) {
    final normalizedVersion = version.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]+'),
      '_',
    );
    return 'gift_ledger_update_$normalizedVersion.$packageType';
  }

  String _joinPath(String directoryPath, String fileName) {
    final separator = Platform.pathSeparator;
    if (directoryPath.endsWith(separator)) {
      return '$directoryPath$fileName';
    }
    return '$directoryPath$separator$fileName';
  }
}
