import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deporte_total_360/regional_stream_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Regional stream policy', () {
    test('defaults playback eligibility checks to Guyana', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await RegionalPlaybackPreferences.getRegionCode(), 'GY');
    });

    test('persists a valid ISO country code', () async {
      SharedPreferences.setMockInitialValues({});
      await RegionalPlaybackPreferences.setRegionCode('BZ');
      expect(await RegionalPlaybackPreferences.getRegionCode(), 'BZ');
    });

    test('rejects invalid region codes', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        () => RegionalPlaybackPreferences.setRegionCode('Guyana'),
        throwsArgumentError,
      );
    });

    test('parses country codes from arrays and delimited strings', () {
      expect(parseAvailableCountryCodes(['gy', 'US', 'not-a-code']), ['GY', 'US']);
      expect(parseAvailableCountryCodes('gy, us;MX|*'), ['GY', 'US', 'MX', '*']);
      expect(parseAvailableCountryCodes('WORLD'), ['*']);
    });

    test('prioritizes sources explicitly available in the selected region', () {
      final ordered = prioritizeRegionalStreamCandidates(
        const <RegionalStreamCandidate>[
          RegionalStreamCandidate(
            url: 'https://media.example/us-only.m3u8',
            availableCountries: ['US'],
          ),
          RegionalStreamCandidate(
            url: 'https://media.example/unknown.m3u8',
          ),
          RegionalStreamCandidate(
            url: 'https://media.example/guyana.m3u8',
            availableCountries: ['GY', 'BB'],
          ),
          RegionalStreamCandidate(
            url: 'https://media.example/global.m3u8',
            availableCountries: ['*'],
          ),
        ],
        regionCode: 'GY',
      );

      expect(
        ordered.map((source) => source.url).toList(),
        <String>[
          'https://media.example/guyana.m3u8',
          'https://media.example/global.m3u8',
          'https://media.example/unknown.m3u8',
        ],
      );
    });

    test('keeps unknown metadata in original order and excludes declared restrictions', () {
      final ordered = prioritizeRegionalStreamCandidates(
        const <RegionalStreamCandidate>[
          RegionalStreamCandidate(url: 'https://media.example/one.m3u8'),
          RegionalStreamCandidate(
            url: 'https://media.example/restricted.m3u8',
            availableCountries: ['US'],
          ),
          RegionalStreamCandidate(url: 'https://media.example/two.m3u8'),
        ],
        regionCode: 'GY',
      );

      expect(ordered.map((source) => source.url).toList(), <String>[
        'https://media.example/one.m3u8',
        'https://media.example/two.m3u8',
      ]);
    });

    test('does not allow credentials or non-http URLs into playback candidates', () {
      final ordered = prioritizeRegionalStreamCandidates(
        const <RegionalStreamCandidate>[
          RegionalStreamCandidate(url: 'https://user:pass@media.example/live.m3u8'),
          RegionalStreamCandidate(url: 'rtmp://media.example/live'),
          RegionalStreamCandidate(url: 'https://media.example/live.m3u8'),
        ],
        regionCode: 'GY',
      );

      expect(ordered, hasLength(1));
      expect(ordered.single.url, 'https://media.example/live.m3u8');
    });

    test('deduplicates URLs without changing the original source URL', () {
      const original = 'https://media.example/live.m3u8?token=keep-me';
      final ordered = prioritizeRegionalStreamCandidates(
        const <RegionalStreamCandidate>[
          RegionalStreamCandidate(url: original),
          RegionalStreamCandidate(url: original),
        ],
        regionCode: 'GY',
      );

      expect(ordered, hasLength(1));
      expect(ordered.single.url, original);
    });
  });
}
