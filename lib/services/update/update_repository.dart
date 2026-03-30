import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/update_manifest.dart';
import '../config_service.dart';
import 'update_keys.dart';

typedef UpdateManifestFetcher = Future<Object?> Function(
    String url, Options options);

class UpdateRepository {
  // Release 包默认走正式 manifest；debug 包默认走测试 manifest，
  // 便于当前分支做闭环验证且不污染正式更新源。
  static const bool useTestingManifest = bool.fromEnvironment(
    'USE_TESTING_UPDATE_SOURCE',
    defaultValue: kDebugMode,
  );
  static const String productionManifestRef = String.fromEnvironment(
    'UPDATE_MANIFEST_REF',
    defaultValue: 'main',
  );
  static const String testingManifestRef = String.fromEnvironment(
    'UPDATE_TESTING_REF',
    defaultValue: 'beat/update-flow',
  );
  static const String productionManifestPath = 'releases/update-manifest.json';
  static const String testingManifestPath =
      'releases/update-manifest.testing.json';

  static String get activeManifestRef =>
      useTestingManifest ? testingManifestRef : productionManifestRef;
  static String get activeManifestPath =>
      useTestingManifest ? testingManifestPath : productionManifestPath;
  static String get _activeManifestRefEncoded =>
      Uri.encodeComponent(activeManifestRef);

  static String get githubContentsApiUrl =>
      'https://api.github.com/repos/final00000000/Gift_Ledger/contents/'
      '$activeManifestPath?ref=$_activeManifestRefEncoded';
  static String get jsDelivrManifestUrl =>
      'https://cdn.jsdelivr.net/gh/final00000000/Gift_Ledger@'
      '$_activeManifestRefEncoded/$activeManifestPath';
  static String get rawManifestUrl =>
      'https://raw.githubusercontent.com/final00000000/Gift_Ledger/'
      '$activeManifestRef/$activeManifestPath';
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/final00000000/Gift_Ledger/releases?per_page=20';
  static const String githubLatestReleasePageUrl =
      'https://github.com/final00000000/Gift_Ledger/releases/latest';
  static const String githubExpandedAssetsUrlPrefix =
      'https://github.com/final00000000/Gift_Ledger/releases/expanded_assets/';

  static List<String> get manifestUrls => <String>[
        githubContentsApiUrl,
        rawManifestUrl,
        jsDelivrManifestUrl,
      ];

  static final RegExp _versionPattern = RegExp(
    r'v?(\d+\.\d+\.\d+(?:-(?!build)[0-9A-Za-z.]+)?)(?=-build|[^0-9A-Za-z.]|$)',
    caseSensitive: false,
  );
  static final RegExp _buildNumberPattern = RegExp(
    r'build[_-]?(\d+)',
    caseSensitive: false,
  );

  UpdateRepository({
    Dio? dio,
    ConfigService? configService,
    UpdateManifestFetcher? fetcher,
  })  : _dio = dio ?? Dio(),
        _configService = configService ?? ConfigService() {
    _fetcher = fetcher ?? _defaultFetch;
  }
  final Dio _dio;
  final ConfigService _configService;
  late final UpdateManifestFetcher _fetcher;

  String? get cachedManifestJson {
    return _configService.getString(updateManifestCacheKey);
  }

  Future<UpdateManifest> fetchManifest() async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final manifestUrl in manifestUrls) {
      try {
        final manifestJson = await _fetchManifestJsonFromUrl(manifestUrl);
        return _saveAndBuildManifest(manifestJson);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        debugPrint(
          'UpdateRepository manifest fetch failed: $manifestUrl -> $error',
        );
      }
    }
    try {
      final releaseFallbackJson = await _fetchManifestJsonFromReleasesApi();
      return _saveAndBuildManifest(releaseFallbackJson);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      debugPrint('UpdateRepository releases API fallback failed: $error');
    }
    try {
      final githubHtmlFallbackJson = await _fetchManifestJsonFromGithubHtml();
      return _saveAndBuildManifest(githubHtmlFallbackJson);
    } catch (error) {
      debugPrint('UpdateRepository GitHub HTML fallback failed: $error');

      final cachedManifest = _tryLoadCachedManifest();
      if (cachedManifest != null) {
        debugPrint('UpdateRepository falling back to cached manifest.');
        return cachedManifest;
      }
      // 优先保留前一个远端失败原因，避免 HTML 兜底覆盖主因。
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
  }

  Future<Map<String, dynamic>> _fetchManifestJsonFromUrl(String url) async {
    final rawJson = await _fetchTextResponse(
      url,
      description: 'update manifest response',
    );
    return _decodeManifestJson(rawJson);
  }

  Future<Map<String, dynamic>> _fetchManifestJsonFromReleasesApi() async {
    final rawJson = await _fetchTextResponse(
      githubReleasesApiUrl,
      description: 'GitHub releases response',
    );
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException(
        'GitHub releases response must be a JSON list.',
      );
    }
    final releases = decoded
        .whereType<Map>()
        .map((release) => Map<String, dynamic>.from(release))
        .toList();

    final stableRelease = _selectLatestRelease(releases, prerelease: false);
    final betaRelease = _selectLatestRelease(releases, prerelease: true);

    return {
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'channels': {
        'stable': _buildChannelJson(stableRelease),
        'beta': _buildChannelJson(betaRelease),
      },
    };
  }

  Future<Map<String, dynamic>> _fetchManifestJsonFromGithubHtml() async {
    final latestReleaseHtml = await _fetchTextResponse(
      githubLatestReleasePageUrl,
      description: 'GitHub latest release page',
    );
    final tag = _extractLatestReleaseTag(latestReleaseHtml);
    final notes = _extractReleaseNotesFromHtml(latestReleaseHtml);
    final expandedAssetsHtml = await _fetchTextResponse(
      '$githubExpandedAssetsUrlPrefix$tag',
      description: 'GitHub expanded assets page',
    );
    final androidEntry = _buildAndroidEntryFromExpandedAssetsHtml(
      tag: tag,
      expandedAssetsHtml: expandedAssetsHtml,
      notes: notes,
    );
    if (androidEntry == null) {
      throw const FormatException(
        'GitHub HTML fallback did not contain any Android APK asset.',
      );
    }
    return {
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'channels': {
        'stable': {'android': androidEntry},
        'beta': <String, dynamic>{},
      },
    };
  }

  Map<String, dynamic>? _selectLatestRelease(
    List<Map<String, dynamic>> releases, {
    required bool prerelease,
  }) {
    for (final release in releases) {
      final isDraft = release['draft'] == true;
      final isPrerelease = release['prerelease'] == true;
      if (isDraft || isPrerelease != prerelease) {
        continue;
      }
      return release;
    }
    return null;
  }

  Map<String, dynamic> _buildChannelJson(Map<String, dynamic>? release) {
    if (release == null) {
      return <String, dynamic>{};
    }
    final androidEntry = _buildAndroidEntryFromRelease(release);
    final result = <String, dynamic>{};
    if (androidEntry != null) {
      result['android'] = androidEntry;
    }
    return result;
  }

  Map<String, dynamic>? _buildAndroidEntryFromRelease(
    Map<String, dynamic> release,
  ) {
    final assets = release['assets'];
    if (assets is! List) {
      return null;
    }
    final normalizedAssets = assets
        .whereType<Map>()
        .map((asset) => Map<String, dynamic>.from(asset))
        .toList();

    final tagName = (release['tag_name'] as String?)?.trim() ?? '';
    final version = _extractVersion(tagName);
    if (version == null || version.isEmpty) {
      return null;
    }
    return _buildAndroidEntryFromAssets(
      assets: normalizedAssets,
      version: version,
      notes: (release['body'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic>? _buildAndroidEntryFromExpandedAssetsHtml({
    required String tag,
    required String expandedAssetsHtml,
    required String notes,
  }) {
    final assetPattern = RegExp(
      r'<a href="([^"]+/releases/download/[^"]+)"[^>]*>\s*'
      r'<span[^>]*class="[^"]*text-bold[^"]*"[^>]*>([^<]+)</span>[\s\S]*?'
      r'<span[^>]*class="[^"]*Truncate-text[^"]*"[^>]*>sha256:([0-9a-fA-F]{64})</span>',
      caseSensitive: false,
    );
    final assets = assetPattern.allMatches(expandedAssetsHtml).map((match) {
      final href = match.group(1)?.trim() ?? '';
      final name = match.group(2)?.trim() ?? '';
      final sha256 = match.group(3)?.trim() ?? '';
      return <String, dynamic>{
        'name': name,
        'browser_download_url': _toAbsoluteGithubUrl(href),
        'digest': 'sha256:$sha256',
      };
    }).toList();

    final version = _extractVersion(tag);
    if (version == null || version.isEmpty) {
      return null;
    }
    return _buildAndroidEntryFromAssets(
      assets: assets,
      version: version,
      notes: notes,
    );
  }

  Map<String, dynamic>? _buildAndroidEntryFromAssets({
    required List<Map<String, dynamic>> assets,
    required String version,
    required String notes,
  }) {
    final apkAssets = _selectAndroidApkAssets(assets, expectedVersion: version);
    if (apkAssets.isEmpty) {
      return null;
    }
    final primaryAsset = _resolvePrimaryAndroidAsset(apkAssets);
    if (primaryAsset == null) {
      return null;
    }
    final primaryInfo = _readAndroidAssetInfo(primaryAsset);
    if (primaryInfo == null) {
      return null;
    }
    final variants = _buildAndroidVariantMap(apkAssets);
    return {
      'version': version,
      'buildNumber': primaryInfo['buildNumber'],
      'downloadUrl': primaryInfo['downloadUrl'],
      'sha256': primaryInfo['sha256'],
      'packageType': 'apk',
      'notes': notes,
      if (variants.isNotEmpty) 'variants': variants,
    };
  }

  Map<String, dynamic> _buildAndroidVariantMap(
    List<Map<String, dynamic>> assets,
  ) {
    final variants = <String, Map<String, dynamic>>{};
    for (final asset in assets) {
      final abi = _matchAndroidAbi(asset);
      if (abi == null ||
          abi == 'universal' ||
          abi == 'x86' ||
          abi == 'x86_64') {
        continue;
      }
      final assetInfo = _readAndroidAssetInfo(asset);
      if (assetInfo == null) {
        continue;
      }
      variants[abi] = {
        'downloadUrl': assetInfo['downloadUrl'],
        'sha256': assetInfo['sha256'],
        'packageType': 'apk',
      };
    }
    return variants;
  }

  Map<String, dynamic>? _readAndroidAssetInfo(Map<String, dynamic> asset) {
    final downloadUrl = (asset['browser_download_url'] as String?)?.trim();
    final digest = (asset['digest'] as String?)?.trim();
    final sha256 = _extractSha256(digest);
    if (downloadUrl == null || downloadUrl.isEmpty || sha256 == null) {
      return null;
    }
    return {
      'downloadUrl': downloadUrl,
      'sha256': sha256,
      'buildNumber': _extractBuildNumber(asset),
    };
  }

  Map<String, dynamic>? _resolvePrimaryAndroidAsset(
    List<Map<String, dynamic>> assets,
  ) {
    final universalAssets = assets.where(_isUniversalAndroidAsset).toList();
    if (universalAssets.isNotEmpty) {
      universalAssets.sort(_compareAndroidApkAssets);
      return universalAssets.first;
    }
    final arm64Assets = assets
        .where((asset) => _matchAndroidAbi(asset) == 'arm64-v8a')
        .toList();
    if (arm64Assets.isNotEmpty) {
      arm64Assets.sort(_compareAndroidApkAssets);
      return arm64Assets.first;
    }
    final armV7Assets = assets
        .where((asset) => _matchAndroidAbi(asset) == 'armeabi-v7a')
        .toList();
    if (armV7Assets.isNotEmpty) {
      armV7Assets.sort(_compareAndroidApkAssets);
      return armV7Assets.first;
    }
    final fallbackAssets = List<Map<String, dynamic>>.from(assets)
      ..sort(_compareAndroidApkAssets);
    return fallbackAssets.isEmpty ? null : fallbackAssets.first;
  }

  List<Map<String, dynamic>> _selectAndroidApkAssets(
    List<Map<String, dynamic>> assets, {
    String? expectedVersion,
  }) {
    var apkAssets = <Map<String, dynamic>>[];
    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url =
          (asset['browser_download_url'] as String?)?.toLowerCase() ?? '';
      final isApk = name.endsWith('.apk') || url.endsWith('.apk');
      if (isApk) {
        apkAssets.add(asset);
      }
    }
    if (apkAssets.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final nonX86Assets = apkAssets.where((asset) {
      final abi = _matchAndroidAbi(asset);
      return abi != 'x86' && abi != 'x86_64';
    }).toList();
    if (nonX86Assets.isNotEmpty) {
      apkAssets = nonX86Assets;
    }
    if (expectedVersion != null && expectedVersion.isNotEmpty) {
      final versionMatchedAssets = apkAssets.where((asset) {
        return _assetContainsVersion(asset, expectedVersion);
      }).toList();
      if (versionMatchedAssets.isNotEmpty) {
        apkAssets = versionMatchedAssets;
      }
      final likelyGiftLedgerAssets = apkAssets.where((asset) {
        return _isLikelyGiftLedgerReleaseAsset(
          asset: asset,
          version: expectedVersion,
        );
      }).toList();
      if (likelyGiftLedgerAssets.isNotEmpty) {
        apkAssets = likelyGiftLedgerAssets;
      }
    }
    final assetsWithBuildNumber = apkAssets.where((asset) {
      return _extractBuildNumber(asset) > 0;
    }).toList();
    if (assetsWithBuildNumber.isNotEmpty) {
      apkAssets = assetsWithBuildNumber;
    }
    apkAssets.sort(_compareAndroidApkAssets);
    return apkAssets;
  }

  int _compareAndroidApkAssets(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftBuildNumber = _extractBuildNumber(left);
    final rightBuildNumber = _extractBuildNumber(right);
    if (leftBuildNumber != rightBuildNumber) {
      return rightBuildNumber.compareTo(leftBuildNumber);
    }
    final leftPriority = _androidAbiPriority(_matchAndroidAbi(left));
    final rightPriority = _androidAbiPriority(_matchAndroidAbi(right));
    if (leftPriority != rightPriority) {
      return leftPriority.compareTo(rightPriority);
    }
    final leftSize = _assetSizeOrMax(left);
    final rightSize = _assetSizeOrMax(right);
    return leftSize.compareTo(rightSize);
  }

  int _androidAbiPriority(String? abi) {
    switch (abi) {
      case 'universal':
        return 0;
      case 'arm64-v8a':
        return 1;
      case 'armeabi-v7a':
        return 2;
      case 'x86_64':
        return 3;
      case 'x86':
        return 4;
      default:
        return 5;
    }
  }

  bool _isUniversalAndroidAsset(Map<String, dynamic> asset) {
    return _matchAndroidAbi(asset) == 'universal';
  }

  String? _matchAndroidAbi(Map<String, dynamic> asset) {
    final candidates = _assetIdentityCandidates(asset);

    for (final candidate in candidates) {
      if (candidate.contains('arm64-v8a') || candidate.contains('arm64')) {
        return 'arm64-v8a';
      }
      if (candidate.contains('armeabi-v7a') ||
          candidate.contains('armeabi') ||
          candidate.contains('arm-v7a') ||
          candidate.contains('armv7')) {
        return 'armeabi-v7a';
      }
      if (candidate.contains('x86_64') || candidate.contains('x86-64')) {
        return 'x86_64';
      }
      if (candidate.contains('x86')) {
        return 'x86';
      }
      if (candidate.contains('universal')) {
        return 'universal';
      }
    }
    return null;
  }

  bool _isLikelyGiftLedgerReleaseAsset({
    required Map<String, dynamic> asset,
    required String version,
  }) {
    final candidates = _assetIdentityCandidates(asset);
    if (!candidates.any((candidate) => candidate.contains('gift_ledger'))) {
      return false;
    }
    if (candidates.any(_containsSuspiciousAssetMarker)) {
      return false;
    }
    return _assetContainsVersion(asset, version);
  }

  bool _containsSuspiciousAssetMarker(String candidate) {
    const suspiciousMarkers = <String>[
      'fasttest',
      'debug',
      'sample',
      'demo',
      'internal',
      'dev',
      'shulu',
    ];
    return suspiciousMarkers.any(candidate.contains);
  }

  bool _assetContainsVersion(Map<String, dynamic> asset, String version) {
    final lowerVersion = version.toLowerCase();
    final assetName = (asset['name'] as String?)?.trim();
    final assetFileName = _assetFileName(asset);
    final extractedVersions = <String>{
      if (_extractVersion(assetName)?.isNotEmpty == true)
        _extractVersion(assetName!)!.toLowerCase(),
      if (_extractVersion(assetFileName)?.isNotEmpty == true)
        _extractVersion(assetFileName)!.toLowerCase(),
    };
    if (extractedVersions.isNotEmpty) {
      return extractedVersions.contains(lowerVersion);
    }

    final candidates = _assetIdentityCandidates(asset);

    for (final candidate in candidates) {
      if (candidate.contains('v$lowerVersion') ||
          candidate.contains(lowerVersion)) {
        return true;
      }
    }
    return false;
  }

  List<String> _assetIdentityCandidates(Map<String, dynamic> asset) {
    final rawUrl = (asset['browser_download_url'] as String?)?.trim();
    final candidates = <String>{
      (asset['name'] as String?)?.trim().toLowerCase() ?? '',
      _assetFileName(asset),
      rawUrl?.toLowerCase() ?? '',
    };
    candidates.removeWhere((candidate) => candidate.isEmpty);
    return candidates.toList(growable: false);
  }

  String _assetFileName(Map<String, dynamic> asset) {
    final rawUrl = (asset['browser_download_url'] as String?)?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      return '';
    }
    return Uri.tryParse(rawUrl)?.pathSegments.last.toLowerCase() ?? '';
  }

  int _assetSizeOrMax(Map<String, dynamic> asset) {
    final rawSize = asset['size'];
    if (rawSize is int) {
      return rawSize;
    }
    if (rawSize is String) {
      return int.tryParse(rawSize) ?? 1 << 30;
    }
    return 1 << 30;
  }

  String? _extractSha256(String? digest) {
    if (digest == null || digest.isEmpty) {
      return null;
    }
    const prefix = 'sha256:';
    if (!digest.toLowerCase().startsWith(prefix)) {
      return null;
    }
    return digest.substring(prefix.length).toLowerCase();
  }

  UpdateManifest _saveAndBuildManifest(Map<String, dynamic> manifestJson) {
    final rawJson = jsonEncode(manifestJson);
    _configService.setString(updateManifestCacheKey, rawJson);
    return UpdateManifest.fromJson(manifestJson);
  }

  UpdateManifest? _tryLoadCachedManifest() {
    final cachedJson = cachedManifestJson;
    if (cachedJson == null || cachedJson.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map) {
        return null;
      }
      return UpdateManifest.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('UpdateRepository cached manifest parse failed: $error');
      return null;
    }
  }

  Future<String> _fetchTextResponse(
    String url, {
    required String description,
  }) async {
    final responseData = await _fetcher(url, _buildRequestOptions(url));
    return _normalizeTextResponse(responseData, description: description);
  }

  Future<Object?> _defaultFetch(String url, Options options) async {
    final response = await _dio.get<Object>(url, options: options);
    return response.data;
  }

  Options _buildRequestOptions(String url) {
    final headers = <String, Object>{'User-Agent': 'GiftLedgerApp/1.0'};
    if (url == githubContentsApiUrl || url == githubReleasesApiUrl) {
      headers['Accept'] = 'application/vnd.github+json';
    }
    return Options(
      responseType: ResponseType.plain,
      headers: headers,
      sendTimeout: const Duration(seconds: 8),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    );
  }

  Map<String, dynamic> _decodeManifestJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    final manifestCandidate = _unwrapGithubContentsResponse(decoded);
    if (manifestCandidate is! Map) {
      throw const FormatException('Update manifest must be a JSON object.');
    }
    return Map<String, dynamic>.from(manifestCandidate);
  }

  dynamic _unwrapGithubContentsResponse(dynamic decoded) {
    if (decoded is! Map) {
      return decoded;
    }
    final content = decoded['content'];
    final encoding = decoded['encoding'];
    if (content is! String) {
      return decoded;
    }
    if (encoding is String && encoding.toLowerCase() != 'base64') {
      throw const FormatException('Unsupported GitHub contents encoding.');
    }
    final normalizedContent = content.replaceAll('\n', '').trim();
    if (normalizedContent.isEmpty) {
      throw const FormatException('GitHub contents response is empty.');
    }
    final nestedJson = utf8.decode(base64Decode(normalizedContent));
    return jsonDecode(nestedJson);
  }

  String _extractLatestReleaseTag(String html) {
    final routeMatch = RegExp(
      "/releases/tag/([^\"'<>?#]+)",
      caseSensitive: false,
    ).firstMatch(html);
    final tagFromRoute = routeMatch?.group(1)?.trim();
    if (tagFromRoute != null && tagFromRoute.isNotEmpty) {
      return tagFromRoute;
    }
    final titleMatch = RegExp(
      r'<title>\s*Release\s+([^<\s]+)',
      caseSensitive: false,
    ).firstMatch(html);
    final tagFromTitle = titleMatch?.group(1)?.trim();
    if (tagFromTitle != null && tagFromTitle.isNotEmpty) {
      return tagFromTitle;
    }
    throw const FormatException(
      'Unable to determine latest GitHub release tag.',
    );
  }

  String _extractReleaseNotesFromHtml(String html) {
    final bodyMatch = RegExp(
      r'<div[^>]*data-test-selector="body-content"[^>]*class="[^"]*markdown-body[^"]*"[^>]*>([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(html);
    if (bodyMatch == null) {
      return '';
    }
    var content = bodyMatch.group(1) ?? '';
    content = content.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    content = content.replaceAll(
      RegExp(r'<li[^>]*>', caseSensitive: false),
      '• ',
    );
    content = content.replaceAll(
      RegExp(
        r'</(p|div|h[1-6]|li|tr|table|thead|tbody|ul|ol)>',
        caseSensitive: false,
      ),
      '\n',
    );
    content = content.replaceAll(
      RegExp(r'</t[dh]>', caseSensitive: false),
      '  ',
    );
    content = content.replaceAll(RegExp(r'<[^>]+>'), '');
    content = _decodeHtmlEntities(content);

    final lines = content
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();

    final normalizedLines = <String>[];
    var previousBlank = false;
    for (final line in lines) {
      if (line.isEmpty) {
        if (normalizedLines.isEmpty || previousBlank) {
          continue;
        }
        normalizedLines.add('');
        previousBlank = true;
        continue;
      }
      normalizedLines.add(line);
      previousBlank = false;
    }
    return normalizedLines.join('\n').trim();
  }

  String _decodeHtmlEntities(String input) {
    final numericEntityPattern = RegExp(r'&#(x?[0-9A-Fa-f]+);');
    var result = input.replaceAllMapped(numericEntityPattern, (match) {
      final rawValue = match.group(1);
      if (rawValue == null || rawValue.isEmpty) {
        return match.group(0) ?? '';
      }
      final isHex = rawValue.startsWith('x') || rawValue.startsWith('X');
      final codePoint = int.tryParse(
        isHex ? rawValue.substring(1) : rawValue,
        radix: isHex ? 16 : 10,
      );
      if (codePoint == null) {
        return match.group(0) ?? '';
      }
      return String.fromCharCode(codePoint);
    });

    const replacements = <String, String>{
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
    };
    replacements.forEach((entity, value) {
      result = result.replaceAll(entity, value);
    });
    return result;
  }

  String _toAbsoluteGithubUrl(String href) {
    final trimmed = href.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://github.com$trimmed';
  }

  String? _extractVersion(String? source) {
    if (source == null) {
      return null;
    }
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = _versionPattern.firstMatch(trimmed);
    return match?.group(1)?.trim();
  }

  int _extractBuildNumber(Map<String, dynamic> asset) {
    final candidates = <String>[
      (asset['name'] as String?)?.trim() ?? '',
      (asset['browser_download_url'] as String?)?.trim() ?? '',
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) {
        continue;
      }
      final match = _buildNumberPattern.firstMatch(candidate);
      final rawValue = match?.group(1);
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }
      final buildNumber = int.tryParse(rawValue);
      if (buildNumber != null) {
        return buildNumber;
      }
    }
    return 0;
  }

  String _normalizeTextResponse(Object? data, {required String description}) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    if (data is Map || data is List) {
      return jsonEncode(data);
    }
    throw FormatException('Empty or invalid $description.');
  }
}
