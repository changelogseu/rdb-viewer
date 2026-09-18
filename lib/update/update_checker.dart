import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// This is the only network call anywhere in RDB Viewer, and it only runs
/// when the user explicitly clicks "Nach Updates suchen" - never
/// automatically on startup or in the background. See the README's
/// "100% local" claim: it stays true unless the user asks otherwise.
const _repoSlug = 'changelogseu/rdb-viewer';
const _releasesUrl = 'https://api.github.com/repos/$_repoSlug/releases/latest';

class ReleaseAsset {
  ReleaseAsset({required this.name, required this.downloadUrl});
  final String name;
  final String downloadUrl;
}

class ReleaseInfo {
  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.assets,
  });

  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final List<ReleaseAsset> assets;

  /// The version numbers from [tagName] (e.g. "v0.1.0" -> [0, 1, 0]),
  /// padded/truncated to 3 components. Non-numeric tags parse as [0, 0, 0]
  /// so they never falsely appear "newer".
  List<int> get versionParts => _parseVersion(tagName);

  /// Best-effort pick of the release asset matching the current OS, based
  /// on the naming convention `.github/workflows/release.yml` produces
  /// (`RDBViewer-windows-x64.zip`, `RDBViewer-macos.zip`).
  ReleaseAsset? assetForCurrentPlatform() {
    final wantWindows = Platform.isWindows;
    final wantMacos = Platform.isMacOS;
    for (final asset in assets) {
      final lower = asset.name.toLowerCase();
      if (wantWindows && lower.contains('windows')) return asset;
      if (wantMacos && lower.contains('macos')) return asset;
    }
    return null;
  }
}

class UpdateCheckResult {
  UpdateCheckResult.upToDate(this.currentVersion)
      : updateAvailable = false,
        release = null;
  UpdateCheckResult.updateAvailable(this.currentVersion, ReleaseInfo this.release)
      : updateAvailable = true;

  final String currentVersion;
  final bool updateAvailable;
  final ReleaseInfo? release;
}

class UpdateCheckException implements Exception {
  UpdateCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}

List<int> _parseVersion(String tag) {
  final cleaned = tag.trim().replaceFirst(RegExp(r'^[vV]'), '');
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(cleaned);
  if (match == null) return [0, 0, 0];
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}

/// Returns > 0 if [a] is newer than [b], < 0 if older, 0 if equal.
int compareVersionParts(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    final diff = a[i] - b[i];
    if (diff != 0) return diff;
  }
  return 0;
}

/// Queries the GitHub Releases API for the latest published release and
/// compares it against the running app's own version (from the platform
/// build metadata via `package_info_plus`, kept in sync with
/// `pubspec.yaml`'s `version:` field by the build tooling).
Future<UpdateCheckResult> checkForUpdate() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse(_releasesUrl))
        .timeout(const Duration(seconds: 10));
    request.headers.set(HttpHeaders.userAgentHeader, 'rdb-viewer-update-check');
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close().timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw UpdateCheckException('Es wurde noch kein Release veröffentlicht.');
    }
    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'GitHub antwortete mit Status ${response.statusCode}.',
      );
    }

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    final release = ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? json['tag_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? 'https://github.com/$_repoSlug/releases',
      assets: [
        for (final a in (json['assets'] as List? ?? []))
          ReleaseAsset(
            name: (a as Map<String, dynamic>)['name'] as String? ?? '',
            downloadUrl: a['browser_download_url'] as String? ?? '',
          ),
      ],
    );

    final isNewer = compareVersionParts(
          release.versionParts,
          _parseVersion(currentVersion),
        ) >
        0;

    return isNewer
        ? UpdateCheckResult.updateAvailable(currentVersion, release)
        : UpdateCheckResult.upToDate(currentVersion);
  } on UpdateCheckException {
    rethrow;
  } on SocketException {
    throw UpdateCheckException(
      'Keine Verbindung zu GitHub möglich. Prüfe deine Internetverbindung.',
    );
  } catch (e) {
    throw UpdateCheckException('Update-Prüfung fehlgeschlagen: $e');
  } finally {
    client.close(force: true);
  }
}
