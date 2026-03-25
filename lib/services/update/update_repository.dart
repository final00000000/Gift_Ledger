import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/update_manifest.dart';
import '../config_service.dart';
import 'update_keys.dart';

typedef UpdateManifestFetcher = Future<Object?> Function(
  String url,
  Options options,
);

class UpdateRepository {
  static const String githubContentsApiUrl =
      'https://api.github.com/repos/final00000000/Gift_Ledger/contents/releases/update-manifest.json?ref=master';
  static const String jsDelivrManifestUrl =
      'https://cdn.jsdelivr.net/gh/final00000000/Gift_Ledger@master/releases/update-manifest.json';
  static const String rawManifestUrl =
      'https://raw.githubusercontent.com/final00000000/Gift_Ledger/master/releases/update-manifest.json';
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/final00000000/Gift_Ledger/releases?per_page=20';
  static const String githubLatestReleasePageUrl =
      'https://github.com/final00000000/Gift_Ledger/releases/latest';
  static const String githubExpandedAssetsUrlPrefix =
      'https://github.com/final00000000/Gift_Ledger/releases/expanded_assets/';

  static const List<String> manifestUrls = <String>[
    githubContentsApiUrl,
    jsDelivrManifestUrl,
    rawManifestUrl,
  ];

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
          'GitHub releases response must be a JSON list.');
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
        'stable': {
          'android': androidEntry,
        },
        'beta': <String, dynamic>{},
      },
    };
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

    final apkAsset = _selectAndroidApkAsset(normalizedAssets);
    if (apkAsset == null) {
      return null;
    }

    final tagName = (release['tag_name'] as String?)?.trim() ?? '';
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    if (version.isEmpty) {
      return null;
    }

    final downloadUrl = (apkAsset['browser_download_url'] as String?)?.trim();
    final digest = (apkAsset['digest'] as String?)?.trim();
    final sha256 = _extractSha256(digest);
    if (downloadUrl == null || downloadUrl.isEmpty || sha256 == null) {
      return null;
    }

    return {
      'version': version,
      'buildNumber': 0,
      'downloadUrl': downloadUrl,
      'sha256': sha256,
      'packageType': 'apk',
      'notes': (release['body'] as String?)?.trim() ?? '',
    };
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

    final apkAsset = _selectAndroidApkAsset(assets);
    if (apkAsset == null) {
      return null;
    }

    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    final downloadUrl = (apkAsset['browser_download_url'] as String?)?.trim();
    final digest = (apkAsset['digest'] as String?)?.trim();
    final sha256 = _extractSha256(digest);
    if (version.isEmpty ||
        downloadUrl == null ||
        downloadUrl.isEmpty ||
        sha256 == null) {
      return null;
    }

    return {
      'version': version,
      'buildNumber': 0,
      'downloadUrl': downloadUrl,
      'sha256': sha256,
      'packageType': 'apk',
      'notes': notes,
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

  Map<String, dynamic>? _selectAndroidApkAsset(
    List<Map<String, dynamic>> assets,
  ) {
    Map<String, dynamic>? fallback;
    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url =
          (asset['browser_download_url'] as String?)?.toLowerCase() ?? '';
      final isApk = name.endsWith('.apk') || url.endsWith('.apk');
      if (!isApk) {
        continue;
      }

      fallback ??= asset;
      if (name.contains('arm64')) {
        return asset;
      }
    }
    return fallback;
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
    final responseData = await _fetcher(
      url,
      _buildRequestOptions(url),
    );
    return _normalizeTextResponse(
      responseData,
      description: description,
    );
  }

  Future<Object?> _defaultFetch(String url, Options options) async {
    final response = await _dio.get<Object>(
      url,
      options: options,
    );
    return response.data;
  }

  Options _buildRequestOptions(String url) {
    final headers = <String, Object>{
      'User-Agent': 'GiftLedgerApp/1.0',
    };
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
        'Unable to determine latest GitHub release tag.');
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

  String _normalizeTextResponse(
    Object? data, {
    required String description,
  }) {
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
