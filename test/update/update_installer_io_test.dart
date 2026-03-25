import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/services/update/update_installer.dart';
import 'package:gift_ledger/services/update/update_installer_io.dart';
import 'package:open_filex/open_filex.dart';

class _FakeDio extends DioForNative {
  _FakeDio({
    this.onDownload,
  }) : super();

  final Future<Response<dynamic>> Function(
    String urlPath,
    String savePath,
    Options? options,
    bool deleteOnError,
    CancelToken? cancelToken,
  )? onDownload;

  Options? lastOptions;
  String? lastUrlPath;
  String? lastSavePath;
  bool? lastDeleteOnError;

  @override
  Future<Response<dynamic>> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    FileAccessMode fileAccessMode = FileAccessMode.write,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) async {
    lastUrlPath = urlPath;
    lastSavePath = savePath as String;
    lastOptions = options;
    lastDeleteOnError = deleteOnError;

    final response = await onDownload?.call(
      urlPath,
      lastSavePath!,
      options,
      deleteOnError,
      cancelToken,
    );
    return response ??
        Response<dynamic>(
          requestOptions: RequestOptions(path: urlPath),
        );
  }
}

UpdateTarget _buildTarget({
  String? downloadUrl = 'https://example.com/gift_ledger.apk',
  String? sha256,
  String? version = '1.3.0',
  String? packageType = 'apk',
}) {
  return UpdateTarget(
    channel: UpdateChannel.stable,
    platform: UpdatePlatform.android,
    version: version,
    buildNumber: 1300,
    downloadUrl: downloadUrl,
    sha256: sha256 ??
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    packageType: packageType,
  );
}

void main() {
  group('IoUpdateInstaller', () {
    test('更新包信息缺失时立即报错', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      final installer = IoUpdateInstaller(
        dio: _FakeDio(),
        directoryProvider: () async => tempDir,
      );

      await expectLater(
        installer.downloadAndOpen(
          _buildTarget(
            downloadUrl: null,
          ),
        ),
        throwsA(
          isA<UpdateInstallerException>().having(
            (error) => error.message,
            'message',
            '更新包信息不完整，暂时无法开始安装。',
          ),
        ),
      );
    });

    test('下载超时时会带超时配置并返回明确错误', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      final dio = _FakeDio(
        onDownload: (urlPath, _, __, ___, ____) async {
          throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: RequestOptions(path: urlPath),
          );
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
        urlLauncher: (_) async => false,
      );

      await expectLater(
        installer.downloadAndOpen(_buildTarget()),
        throwsA(
          isA<UpdateInstallerException>().having(
            (error) => error.message,
            'message',
            '下载更新包超时，请检查网络后重试。',
          ),
        ),
      );

      expect(dio.lastDeleteOnError, isTrue);
      expect(dio.lastOptions?.connectTimeout, const Duration(seconds: 15));
      expect(dio.lastOptions?.sendTimeout, const Duration(seconds: 15));
      expect(dio.lastOptions?.receiveTimeout, const Duration(seconds: 45));
      expect(dio.lastOptions?.followRedirects, isTrue);
      expect(dio.lastOptions?.maxRedirects, 5);
      expect(dio.lastOptions?.headers?['User-Agent'], 'GiftLedgerApp/1.0');
    });

    test('下载超时后会回退到系统浏览器下载', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      Uri? launchedUri;
      final dio = _FakeDio(
        onDownload: (urlPath, _, __, ___, ____) async {
          throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: RequestOptions(path: urlPath),
          );
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final result = await installer.downloadAndOpen(_buildTarget());

      expect(result.didOpen, isTrue);
      expect(result.savePath, 'https://example.com/gift_ledger.apk');
      expect(result.message, '应用内下载较慢，已打开系统浏览器下载更新，请下载完成后安装。');
      expect(launchedUri, Uri.parse('https://example.com/gift_ledger.apk'));
    });

    test('总下载超时后会回退到系统浏览器下载', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      Uri? launchedUri;
      final dio = _FakeDio(
        onDownload: (urlPath, _, __, ___, cancelToken) async {
          final cancelError = await cancelToken!.whenCancel;
          throw cancelError;
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
        downloadTotalTimeout: const Duration(milliseconds: 10),
      );

      final result = await installer.downloadAndOpen(_buildTarget());

      expect(result.didOpen, isTrue);
      expect(result.message, '应用内下载较慢，已打开系统浏览器下载更新，请下载完成后安装。');
      expect(launchedUri, Uri.parse('https://example.com/gift_ledger.apk'));
    });

    test('连接异常后会回退到系统浏览器下载', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      Uri? launchedUri;
      final dio = _FakeDio(
        onDownload: (urlPath, _, __, ___, ____) async {
          throw DioException(
            requestOptions: RequestOptions(path: urlPath),
            type: DioExceptionType.connectionError,
            error: const SocketException('network unreachable'),
          );
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final result = await installer.downloadAndOpen(_buildTarget());

      expect(result.didOpen, isTrue);
      expect(result.message, '应用内下载较慢，已打开系统浏览器下载更新，请下载完成后安装。');
      expect(launchedUri, Uri.parse('https://example.com/gift_ledger.apk'));
    });

    test('未知 SocketException 后会回退到系统浏览器下载', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      Uri? launchedUri;
      final dio = _FakeDio(
        onDownload: (urlPath, _, __, ___, ____) async {
          throw DioException(
            requestOptions: RequestOptions(path: urlPath),
            type: DioExceptionType.unknown,
            error: const SocketException('operation timed out'),
          );
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final result = await installer.downloadAndOpen(_buildTarget());

      expect(result.didOpen, isTrue);
      expect(result.message, '应用内下载较慢，已打开系统浏览器下载更新，请下载完成后安装。');
      expect(launchedUri, Uri.parse('https://example.com/gift_ledger.apk'));
    });

    test('安装包校验失败时会删除临时文件', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      final dio = _FakeDio(
        onDownload: (_, savePath, __, ___, ____) async {
          final file = File(savePath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(const <int>[1, 2, 3, 4]);
          return Response<void>(
            requestOptions: RequestOptions(path: 'https://example.com'),
          );
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
      );

      await expectLater(
        installer.downloadAndOpen(
          _buildTarget(
            sha256:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        ),
        throwsA(
          isA<UpdateInstallerException>().having(
            (error) => error.message,
            'message',
            '安装包校验失败，请重新检查更新后再试。',
          ),
        ),
      );

      expect(dio.lastSavePath, isNotNull);
      expect(File(dio.lastSavePath!).existsSync(), isFalse);
    });

    test('安装器打开失败时返回明确错误', () async {
      final tempDir = await Directory.systemTemp.createTemp('installer-test');
      final content = utf8.encode('gift-ledger');
      final expectedSha256 = crypto.sha256.convert(content).toString();
      final dio = _FakeDio(
        onDownload: (_, savePath, __, ___, ____) async {
          final file = File(savePath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(content);
          return Response<void>(
            requestOptions: RequestOptions(path: 'https://example.com'),
          );
        },
      );
      final installer = IoUpdateInstaller(
        dio: dio,
        directoryProvider: () async => tempDir,
        fileOpener: (_) async => OpenResult(
          type: ResultType.error,
          message: 'File opened incorrectly。',
        ),
      );

      await expectLater(
        installer.downloadAndOpen(
          _buildTarget(
            sha256: expectedSha256,
          ),
        ),
        throwsA(
          isA<UpdateInstallerException>().having(
            (error) => error.message,
            'message',
            '无法打开系统安装器：File opened incorrectly。',
          ),
        ),
      );
    });
  });
}
