import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/update_target.dart';
import 'update_installer.dart';

typedef DownloadDirectoryProvider = Future<Directory> Function();
typedef FileOpener = Future<OpenResult> Function(String filePath);
typedef UrlLauncher = Future<bool> Function(Uri uri);
typedef UpdateDownloader = Future<void> Function({
  required Dio dio,
  required String url,
  required String savePath,
  required bool deleteOnError,
  required Options options,
  required CancelToken cancelToken,
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

Future<bool> _defaultUrlLauncher(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> defaultUpdateDownloader({
  required Dio dio,
  required String url,
  required String savePath,
  required bool deleteOnError,
  required Options options,
  required CancelToken cancelToken,
}) async {
  int lastLoggedPercent = -1;

  await dio.download(
    url,
    savePath,
    deleteOnError: deleteOnError,
    options: options,
    cancelToken: cancelToken,
    onReceiveProgress: (received, total) {
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
  UrlLauncher? urlLauncher,
  UpdateDownloader? downloader,
  Duration downloadTotalTimeout = IoUpdateInstaller.defaultDownloadTotalTimeout,
}) {
  return IoUpdateInstaller(
    dio: dio,
    directoryProvider: directoryProvider,
    fileOpener: fileOpener,
    urlLauncher: urlLauncher,
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
    UrlLauncher? urlLauncher,
    UpdateDownloader? downloader,
    Duration downloadTotalTimeout = defaultDownloadTotalTimeout,
  })  : _dio = dio ?? Dio(),
        _directoryProvider = directoryProvider ?? getTemporaryDirectory,
        _fileOpener = fileOpener ?? _defaultPackageFileOpener,
        _urlLauncher = urlLauncher ?? _defaultUrlLauncher,
        _downloader = downloader ?? defaultUpdateDownloader,
        _downloadTotalTimeout = downloadTotalTimeout;

  final Dio _dio;
  final DownloadDirectoryProvider _directoryProvider;
  final FileOpener _fileOpener;
  final UrlLauncher _urlLauncher;
  final UpdateDownloader _downloader;
  final Duration _downloadTotalTimeout;

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
        '更新包信息不完整，暂时无法开始安装。',
      );
    }

    final directory = await _directoryProvider();
    final savePath = _joinPath(
      directory.path,
      _buildFileName(version: version, packageType: packageType),
    );
    final cancelToken = CancelToken();
    var triggeredByTotalTimeout = false;
    Timer? totalTimeoutTimer;

    try {
      totalTimeoutTimer = Timer(_downloadTotalTimeout, () {
        triggeredByTotalTimeout = true;
        if (!cancelToken.isCancelled) {
          cancelToken.cancel(_downloadTimeoutReason);
        }
      });

      await _downloader(
        dio: _dio,
        url: downloadUrl,
        savePath: savePath,
        deleteOnError: true,
        options: _buildDownloadOptions(),
        cancelToken: cancelToken,
      );
      totalTimeoutTimer.cancel();
    } on DioException catch (error) {
      totalTimeoutTimer?.cancel();

      final didFallbackToBrowser = await _tryFallbackToBrowser(
        downloadUrl: downloadUrl,
        triggeredByTotalTimeout: triggeredByTotalTimeout,
        error: error,
      );
      if (didFallbackToBrowser) {
        await _deleteIfExists(savePath);
        return InstallResult(
          didOpen: true,
          savePath: downloadUrl,
          message: '应用内下载较慢，已打开系统浏览器下载更新，请下载完成后安装。',
        );
      }

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

    final openResult = await _fileOpener(savePath);
    if (openResult.type != ResultType.done) {
      throw UpdateInstallerException('无法打开系统安装器：${openResult.message}');
    }

    return InstallResult(
      didOpen: true,
      savePath: savePath,
      message: _normalizeOpenResultMessage(openResult.message),
    );
  }

  Future<bool> _tryFallbackToBrowser({
    required String downloadUrl,
    required bool triggeredByTotalTimeout,
    required DioException error,
  }) async {
    if (!_shouldFallbackToBrowser(
      error: error,
      triggeredByTotalTimeout: triggeredByTotalTimeout,
    )) {
      return false;
    }

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      return false;
    }

    try {
      return await _urlLauncher(uri);
    } catch (_) {
      return false;
    }
  }

  bool _shouldFallbackToBrowser({
    required DioException error,
    required bool triggeredByTotalTimeout,
  }) {
    if (triggeredByTotalTimeout) {
      return true;
    }

    final errorMessage = (error.message ?? '').toLowerCase();

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.cancel:
        return error.error == _downloadTimeoutReason ||
            error.message == _downloadTimeoutReason;
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        return error.error is SocketException ||
            errorMessage.contains('timed out');
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
        return false;
    }
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
