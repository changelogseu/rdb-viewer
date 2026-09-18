import 'package:flutter_test/flutter_test.dart';
import 'package:rdb_viewer/update/update_checker.dart';

ReleaseInfo _release(String tag, {List<ReleaseAsset> assets = const []}) => ReleaseInfo(
      tagName: tag,
      name: tag,
      body: '',
      htmlUrl: 'https://example.invalid/release',
      assets: assets,
    );

void main() {
  group('compareVersionParts', () {
    test('detects a newer patch version', () {
      expect(compareVersionParts([0, 1, 1], [0, 1, 0]) > 0, isTrue);
    });

    test('detects an older major version', () {
      expect(compareVersionParts([1, 0, 0], [2, 0, 0]) < 0, isTrue);
    });

    test('treats equal versions as equal', () {
      expect(compareVersionParts([1, 2, 3], [1, 2, 3]), 0);
    });
  });

  group('ReleaseInfo.versionParts', () {
    test('parses a "v"-prefixed tag', () {
      expect(_release('v0.1.0').versionParts, [0, 1, 0]);
    });

    test('parses a tag without the "v" prefix', () {
      expect(_release('2.10.3').versionParts, [2, 10, 3]);
    });

    test('falls back to [0, 0, 0] for a non-semver tag', () {
      expect(_release('nightly').versionParts, [0, 0, 0]);
    });
  });

  group('ReleaseInfo.assetForCurrentPlatform', () {
    test('returns null when no asset matches any known platform name', () {
      final release = _release('v0.1.0', assets: [
        ReleaseAsset(name: 'source.tar.gz', downloadUrl: 'https://example.invalid/src'),
      ]);
      expect(release.assetForCurrentPlatform(), isNull);
    });
  });
}
