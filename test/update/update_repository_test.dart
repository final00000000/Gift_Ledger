import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/update/update_keys.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _buildManifestJson({String version = '1.3.0'}) {
  return {
    'schemaVersion': 1,
    'generatedAt': '2026-03-25T00:00:00Z',
    'channels': {
      'stable': {
        'android': {
          'version': version,
          'buildNumber': 9,
          'downloadUrl':
              'https://github.com/final00000000/Gift_Ledger/releases/download/v1.3.0/app-release.apk',
          'sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'packageType': 'apk',
          'notes': '稳定版更新',
        },
      },
      'beta': {},
    },
  };
}

List<Map<String, dynamic>> _buildReleasesJson({
  String stableVersion = '1.2.8',
  String betaVersion = '1.2.9-beta.1',
}) {
  return <Map<String, dynamic>>[
    {
      'tag_name': 'v$stableVersion',
      'draft': false,
      'prerelease': false,
      'body': '稳定版发布说明',
      'assets': [
        {
          'name': 'gift_ledger_v${stableVersion}_armeabi_build1200.apk',
          'browser_download_url':
              'https://github.com/final00000000/Gift_Ledger/releases/download/v$stableVersion/gift_ledger_v${stableVersion}_armeabi_build1200.apk',
          'digest':
              'sha256:1111111111111111111111111111111111111111111111111111111111111111',
          'size': 20300781,
        },
        {
          'name': 'gift_ledger_v${stableVersion}_arm64_build1300.apk',
          'browser_download_url':
              'https://github.com/final00000000/Gift_Ledger/releases/download/v$stableVersion/gift_ledger_v${stableVersion}_arm64_build1300.apk',
          'digest':
              'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 26780586,
        },
      ],
    },
    {
      'tag_name': 'v$betaVersion',
      'draft': false,
      'prerelease': true,
      'body': 'Beta 发布说明',
      'assets': [
        {
          'name': 'gift_ledger_v1.2.9_beta_arm64_build1312.apk',
          'browser_download_url':
              'https://github.com/final00000000/Gift_Ledger/releases/download/v$betaVersion/gift_ledger_v1.2.9_beta_arm64_build1312.apk',
          'digest':
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        },
      ],
    },
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configService = ConfigService();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configService.init();
  });

  setUp(() async {
    await configService.clear();
  });

  test('UpdateRepository 支持解析 GitHub contents API 的 base64 manifest', () async {
    final rawManifest = jsonEncode(_buildManifestJson(version: '1.3.2'));
    final githubContentsPayload = jsonEncode({
      'encoding': 'base64',
      'content': base64Encode(utf8.encode(rawManifest)),
    });

    final repository = UpdateRepository(
      configService: configService,
      fetcher: (url, options) async {
        expect(url, UpdateRepository.githubContentsApiUrl);
        expect(options.headers?['Accept'], 'application/vnd.github+json');
        return githubContentsPayload;
      },
    );

    final manifest = await repository.fetchManifest();

    expect(manifest.stable.android?.version, '1.3.2');
    expect(configService.getString(updateManifestCacheKey), rawManifest);
  });

  test('UpdateRepository 当前置地址失败时会回退到后续地址', () async {
    final rawManifest = jsonEncode(_buildManifestJson(version: '1.3.3'));
    final visitedUrls = <String>[];

    final repository = UpdateRepository(
      configService: configService,
      fetcher: (url, options) async {
        visitedUrls.add(url);
        if (url == UpdateRepository.githubContentsApiUrl) {
          throw DioException(
            requestOptions: RequestOptions(path: url),
            error: 'blocked',
          );
        }
        if (url == UpdateRepository.rawManifestUrl) {
          return rawManifest;
        }
        throw StateError('should not reach raw fallback');
      },
    );

    final manifest = await repository.fetchManifest();

    expect(manifest.stable.android?.version, '1.3.3');
    expect(
      visitedUrls,
      <String>[
        UpdateRepository.githubContentsApiUrl,
        UpdateRepository.rawManifestUrl,
      ],
    );
  });

  test('UpdateRepository 会过滤可疑测试 APK，并优先选择正式的 arm64 更新包', () async {
    final repository = UpdateRepository(
      configService: configService,
      fetcher: (url, options) async {
        if (url == UpdateRepository.githubReleasesApiUrl) {
          return jsonEncode([
            {
              'tag_name': 'v1.3.1',
              'draft': false,
              'prerelease': false,
              'body': '体积优化测试',
              'assets': [
                {
                  'name': 'gift_ledger-stable-android-v1.2.8-build8.apk',
                  'browser_download_url':
                      'https://github.com/final00000000/Gift_Ledger/releases/download/v1.3.1/gift_ledger-stable-android-v1.2.8-build8.apk',
                  'digest':
                      'sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
                  'size': 66005243,
                },
                {
                  'name': 'gift_ledger_v1.3.1_arm64_big_build1309.apk',
                  'browser_download_url':
                      'https://github.com/final00000000/Gift_Ledger/releases/download/v1.3.1/gift_ledger_v1.3.1_arm64_big_build1309.apk',
                  'digest':
                      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                  'size': 26780586,
                },
                {
                  'name': 'gift_ledger_v1.3.1_arm64_fasttest_build1310.apk',
                  'browser_download_url':
                      'https://github.com/final00000000/Gift_Ledger/releases/download/v1.3.1/gift_ledger_v1.3.1_arm64_fasttest_build1310.apk',
                  'digest':
                      'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                  'size': 11731255,
                },
              ],
            },
          ]);
        }

        throw DioException(
          requestOptions: RequestOptions(path: url),
          error: '404',
        );
      },
    );

    final manifest = await repository.fetchManifest();

    expect(manifest.stable.android?.downloadUrl,
        'https://github.com/final00000000/Gift_Ledger/releases/download/v1.3.1/gift_ledger_v1.3.1_arm64_big_build1309.apk');
    expect(manifest.stable.android?.sha256,
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    expect(manifest.stable.android?.buildNumber, 1309);
  });

  test('UpdateRepository 会在 manifest 全部失败后回退 GitHub Releases API', () async {
    final visitedUrls = <String>[];

    final repository = UpdateRepository(
      configService: configService,
      fetcher: (url, options) async {
        visitedUrls.add(url);
        if (url == UpdateRepository.githubReleasesApiUrl) {
          expect(options.headers?['Accept'], 'application/vnd.github+json');
          return jsonEncode(_buildReleasesJson());
        }

        throw DioException(
          requestOptions: RequestOptions(path: url),
          error: '404',
        );
      },
    );

    final manifest = await repository.fetchManifest();

    expect(
      visitedUrls,
      <String>[
        UpdateRepository.githubContentsApiUrl,
        UpdateRepository.rawManifestUrl,
        UpdateRepository.jsDelivrManifestUrl,
        UpdateRepository.githubReleasesApiUrl,
      ],
    );
    expect(manifest.stable.android?.version, '1.2.8');
    expect(manifest.stable.android?.buildNumber, 1300);
    expect(
      manifest.stable.android?.downloadUrl,
      'https://github.com/final00000000/Gift_Ledger/releases/download/v1.2.8/gift_ledger_v1.2.8_arm64_build1300.apk',
    );
    expect(
      manifest.stable.android?.sha256,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(manifest.stable.android?.notes, '稳定版发布说明');
    expect(manifest.beta.android?.version, '1.2.9-beta.1');
    expect(manifest.beta.android?.buildNumber, 1312);
  });
  test('UpdateRepository 会在 API 也不可用时回退 GitHub Release HTML', () async {
    final visitedUrls = <String>[];
    const latestReleaseHtml = '''
<html>
  <head>
    <title>Release v1.2.8 - 免 VPN 更新测试</title>
    <meta name="apple-itunes-app" content="app-argument=https://github.com/final00000000/Gift_Ledger/releases/tag/v1.2.8">
  </head>
  <body>
    <div data-test-selector="body-content" class="markdown-body tmp-my-3">
      <h2>✨ 更新内容</h2>
      <ul>
        <li>无需 VPN 也能检查更新</li>
      </ul>
    </div>
  </body>
</html>
''';
    const expandedAssetsHtml = '''
<div class="Box Box--condensed tmp-mt-3">
  <ul>
    <li class="Box-row d-flex flex-column flex-md-row">
      <a href="/final00000000/Gift_Ledger/releases/download/v1.2.8/gift_ledger_v1.2.8_arm64_build1300.apk" class="Truncate">
        <span class="Truncate-text text-bold">gift_ledger_v1.2.8_arm64_build1300.apk</span>
      </a>
      <span class="Truncate-text">sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc</span>
    </li>
  </ul>
</div>
''';

    final repository = UpdateRepository(
      configService: configService,
      fetcher: (url, options) async {
        visitedUrls.add(url);
        if (url == UpdateRepository.githubLatestReleasePageUrl) {
          return latestReleaseHtml;
        }
        if (url == '${UpdateRepository.githubExpandedAssetsUrlPrefix}v1.2.8') {
          return expandedAssetsHtml;
        }

        throw DioException(
          requestOptions: RequestOptions(path: url),
          error: 'blocked',
        );
      },
    );

    final manifest = await repository.fetchManifest();

    expect(
      visitedUrls,
      <String>[
        UpdateRepository.githubContentsApiUrl,
        UpdateRepository.rawManifestUrl,
        UpdateRepository.jsDelivrManifestUrl,
        UpdateRepository.githubReleasesApiUrl,
        UpdateRepository.githubLatestReleasePageUrl,
        '${UpdateRepository.githubExpandedAssetsUrlPrefix}v1.2.8',
      ],
    );
    expect(manifest.stable.android?.version, '1.2.8');
    expect(manifest.stable.android?.buildNumber, 1300);
    expect(
      manifest.stable.android?.downloadUrl,
      'https://github.com/final00000000/Gift_Ledger/releases/download/v1.2.8/gift_ledger_v1.2.8_arm64_build1300.apk',
    );
    expect(
      manifest.stable.android?.sha256,
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
    expect(manifest.stable.android?.notes, contains('无需 VPN 也能检查更新'));
    expect(manifest.beta.android, isNull);
  });

  test('UpdateRepository 远端全部失败时会回退本地缓存 manifest', () async {
    final cachedManifest = jsonEncode(_buildManifestJson(version: '1.2.8'));
    await configService.setString(updateManifestCacheKey, cachedManifest);

    final repository = UpdateRepository(
      configService: configService,
      fetcher: (url, options) async {
        throw DioException(
          requestOptions: RequestOptions(path: url),
          error: 'network down',
        );
      },
    );

    final manifest = await repository.fetchManifest();

    expect(manifest.stable.android?.version, '1.2.8');
    expect(manifest.stable.android?.downloadUrl, isNotEmpty);
    expect(configService.getString(updateManifestCacheKey), cachedManifest);
  });
}
