import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/update_target.dart';
import 'update_installer.dart';

typedef DownloadDirectoryProvider = Future<Directory> Function();
typedef FileOpener = Future<OpenResult> Function(String filePath);
typedef InstallPermissionChecker = Future<bool> Function();
typedef InstallPermissionRequester = Future<bool> Function();
typedef UpdateDownloader = Future<void> Function({
  required Dio dio,
  required String url,
  required String savePath,
  required bool deleteOnError,
  required Options options,
  required CancelToken cancelToken,
  ProgressCallback? onReceiveProgress,
});

const MethodChannel _appInstallerChannel = MethodChannel(
  'com.giftmoney.gift_ledger/app_installer',
);

Future<OpenResult> _defaultPackageFileOpener(String filePath) async {
  if (!Platform.isAndroid) {
    return OpenFilex.open(filePath);
  }

  try {
    final didLaunch = await _appInstallerChannel.invokeMethod<bool>(
      'installApk',
      <String, Object>{'filePath': filePath},
    );

    if (didLaunch == true) {
      return OpenResult(type: ResultType.done, message: 'done');
    }

    return OpenResult(
      type: ResultType.error,
      message: '系统安装器启动失败。',
    );
  } on PlatformException catch (error) {
    return OpenResult(
      type: ResultType.error,
      message: error.message ?? '系统安装器启动失败。',
    );
  } catch (_) {
    return OpenResult(
      type: ResultType.error,
      message: '系统安装器启动失败。',
    );
  }
}

Future<bool> _defaultInstallPermissionChecker() async {
  if (!Platform.isAndroid) {
    return true;
  }

  try {
    final granted = await _appInstallerChannel.invokeMethod<bool>(
      'canInstallPackages',
    );
    return granted ?? false;
  } on PlatformException catch (error) {
    throw UpdateInstallerException(
      error.message ?? '无法检查安装权限，请稍后重试。',
    );
  } catch (_) {
    throw const UpdateInstallerException('无法检查安装权限，请稍后重试。');
  }
}

Future<bool> _defaultInstallPermissionRequester() async {
  if (!Platform.isAndroid) {
    return true;
  }

  try {
    final opened = await _appInstallerChannel.invokeMethod<bool>(
      'openInstallPermissionSettings',
    );
    return opened ?? false;
  } on PlatformException catch (error) {
    throw UpdateInstallerException(
      error.message ?? '无法打开安装权限设置页，请稍后重试。',
    );
  } catch (_) {
    throw const UpdateInstallerException('无法打开安装权限设置页，请稍后重试。');
  }
}

Future<void> defaultUpdateDownloader({
  required Dio dio,
  required String url,
  required String savePath,
  required bool deleteOnError,
  required Options options,
  required CancelToken cancelToken,
  ProgressCallback? onReceiveProgress,
}) async {
  int lastLoggedPercent = -1;

  await dio.download(
    url,
    savePath,
    deleteOnError: deleteOnError,
    options: options,
    cancelToken: cancelToken,
    onReceiveProgress: (received, total) {
      onReceiveProgress?.call(received, total);

      if (!kDebugMode || total <= 0) {
        return;
      }

      final percent = ((received / total) * 100).floor();
      if (percent == lastLoggedPercent || percent % 10 != 0) {
        return;
      }

      lastLoggedPercent = percent;
      debugPrint(
        'IoUpdateInstaller downloading... $percent% '
        '($received/$total)',
      );
    },
  );
}

UpdateInstaller createUpdateInstaller({
  Dio? dio,
  DownloadDirectoryProvider? directoryProvider,
  FileOpener? fileOpener,
  InstallPermissionChecker? installPermissionChecker,
  InstallPermissionRequester? installPermissionRequester,
  UpdateDownloader? downloader,
  Duration downloadTotalTimeout = IoUpdateInstaller.defaultDownloadTotalTimeout,
}) {
  return IoUpdateInstaller(
    dio: dio,
    directoryProvider: directoryProvider,
    fileOpener: fileOpener,
    installPermissionChecker: installPermissionChecker,
    installPermissionRequester: installPermissionRequester,
    downloader: downloader,
    downloadTotalTimeout: downloadTotalTimeout,
  );
}

class IoUpdateInstaller implements UpdateInstaller {
  static const Duration defaultDownloadTotalTimeout = Duration(seconds: 60);
  static const Duration _downloadConnectTimeout = Duration(seconds: 15);
  static const Duration _downloadSendTimeout = Duration(seconds: 15);
  static const Duration _downloadReceiveTimeout = Duration(seconds: 45);
  static const String _downloadTimeoutReason = 'download_total_timeout';

  IoUpdateInstaller({
    Dio? dio,
    DownloadDirectoryProvider? directoryProvider,
    FileOpener? fileOpener,
    InstallPermissionChecker? installPermissionChecker,
    InstallPermissionRequester? installPermissionRequester,
    UpdateDownloader? downloader,
    Duration downloadTotalTimeout = defaultDownloadTotalTimeout,
  })  : _dio = dio ?? Dio(),
        _directoryProvider = directoryProvider ?? getTemporaryDirectory,
        _fileOpener = fileOpener ?? _defaultPackageFileOpener,
        _installPermissionChecker =
            installPermissionChecker ?? _defaultInstallPermissionChecker,
        _installPermissionRequester =
            installPermissionRequester ?? _defaultInstallPermissionRequester,
        _downloader = downloader ?? defaultUpdateDownloader,
        _downloadTotalTimeout = downloadTotalTimeout;

  final Dio _dio;
  final DownloadDirectoryProvider _directoryProvider;
  final FileOpener _fileOpener;
  final InstallPermissionChecker _installPermissionChecker;
  final InstallPermissionRequester _installPermissionRequester;
  final UpdateDownloader _downloader;
  final Duration _downloadTotalTimeout;

  @override
  Future<bool> canInstallPackages() {
    return _installPermissionChecker();
  }

  @override
  Future<bool> requestInstallPermission() {
    return _installPermissionRequester();
  }

  @override
  Future<InstallResult> downloadAndOpen(
    UpdateTarget target, {
    DownloadProgressCallback? onProgress,
  }) async {
    final downloadUrl = target.downloadUrl;
    final sha256 = target.sha256;
    final version = target.version;
    final packageType = target.packageType;

    if (downloadUrl == null ||
        sha256 == null ||
        version == null ||
        packageType == null) {
      throw const UpdateInstallerException(
        '更新包信息不完整，暂时无法开始安装。',
      );
    }

    final directory = await _directoryProvider();
    final savePath = _joinPath(
      directory.path,
      _buildFileName(version: version, packageType: packageType),
    );
    final cancelToken = CancelToken();
    int lastReceivedBytes = 0;
    var triggeredByTotalTimeout = false;
    Timer? totalTimeoutTimer;

    void restartTotalTimeoutTimer() {
      totalTimeoutTimer?.cancel();
      totalTimeoutTimer = Timer(_downloadTotalTimeout, () {
        triggeredByTotalTimeout = true;
        if (!cancelToken.isCancelled) {
          cancelToken.cancel(_downloadTimeoutReason);
        }
      });
    }

    try {
      debugPrint('IoUpdateInstaller start download: $downloadUrl');
      restartTotalTimeoutTimer();

      await _downloader(
        dio: _dio,
        url: downloadUrl,
        savePath: savePath,
        deleteOnError: true,
        options: _buildDownloadOptions(),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          onProgress?.call(
            DownloadProgress(
              receivedBytes: received,
              totalBytes: total,
            ),
          );

          if (received <= lastReceivedBytes) {
            return;
          }

          lastReceivedBytes = received;
          restartTotalTimeoutTimer();
          if (kDebugMode) {
            debugPrint(
              'IoUpdateInstaller keepalive: received=$received total=$total',
            );
          }
        },
      );
      totalTimeoutTimer?.cancel();
    } on DioException catch (error) {
      totalTimeoutTimer?.cancel();
      debugPrint(
        'IoUpdateInstaller download failed: '
        'type=${error.type}, '
        'message=${error.message}, '
        'error=${error.error}, '
        'timedOut=$triggeredByTotalTimeout, '
        'received=$lastReceivedBytes',
      );

      await _deleteIfExists(savePath);
      throw UpdateInstallerException(
        _buildDownloadErrorMessage(
          error,
          triggeredByTotalTimeout: triggeredByTotalTimeout,
        ),
      );
    } catch (_) {
      totalTimeoutTimer?.cancel();
      await _deleteIfExists(savePath);
      throw const UpdateInstallerException('下载更新包失败，请稍后重试。');
    }

    final actualSha256 = await _computeSha256(savePath);
    if (actualSha256 != sha256.toLowerCase()) {
      await _deleteIfExists(savePath);
      throw const UpdateInstallerException('安装包校验失败，请重新检查更新后再试。');
    }

    return _openDownloadedPackage(savePath);
  }

  @override
  Future<InstallResult> reopenDownloadedPackage(String filePath) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty ||
        normalizedPath.startsWith('http://') ||
        normalizedPath.startsWith('https://')) {
      throw const UpdateInstallerException('安装包不存在，请重新下载更新。');
    }

    final packageFile = File(normalizedPath);
    if (!await packageFile.exists()) {
      throw const UpdateInstallerException('安装包不存在，请重新下载更新。');
    }

    return _openDownloadedPackage(normalizedPath);
  }

  Future<InstallResult> _openDownloadedPackage(String filePath) async {
    final openResult = await _fileOpener(filePath);
    if (openResult.type != ResultType.done) {
      throw UpdateInstallerException('无法打开系统安装器：${openResult.message}');
    }

    return InstallResult(
      didOpen: true,
      savePath: filePath,
      message: _normalizeOpenResultMessage(openResult.message),
    );
  }

  Options _buildDownloadOptions() {
    return Options(
      headers: const <String, Object>{
        'User-Agent': 'GiftLedgerApp/1.0',
      },
      connectTimeout: _downloadConnectTimeout,
      sendTimeout: _downloadSendTimeout,
      receiveTimeout: _downloadReceiveTimeout,
      followRedirects: true,
      maxRedirects: 5,
    );
  }

  String _buildDownloadErrorMessage(
    DioException error, {
    required bool triggeredByTotalTimeout,
  }) {
    if (triggeredByTotalTimeout) {
      return '下载更新包超时，请检查网络后重试。';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '下载更新包超时，请检查网络后重试。';
      case DioExceptionType.connectionError:
        return '当前网络无法访问更新包，请稍后重试。';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == null) {
          return '更新包下载失败，请稍后重试。';
        }
        return '更新包下载失败（HTTP $statusCode），请稍后重试。';
      case DioExceptionType.cancel:
        if (error.error == _downloadTimeoutReason ||
            error.message == _downloadTimeoutReason) {
          return '下载更新包超时，请检查网络后重试。';
        }
        return '更新下载已取消。';
      case DioExceptionType.badCertificate:
        return '更新包证书校验失败，请稍后重试。';
      case DioExceptionType.unknown:
        final rootError = error.error;
        if (rootError is SocketException) {
          return '当前网络不可用，请检查网络后重试。';
        }
        return '下载更新包失败，请稍后重试。';
    }
  }

  String _normalizeOpenResultMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'done') {
      return '已打开系统安装器，请按提示完成更新。';
    }
    return trimmed;
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
