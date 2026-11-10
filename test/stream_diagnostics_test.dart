import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deporte_total_360/stream_diagnostics.dart';

void main() {
  group('StreamDiagnosticsService', () {
    test('403 is reported as possible GeoIP, not confirmed without evidence', () async {
      final client = MockClient((request) async => http.Response('Forbidden', 403));
      addTearDown(client.close);
      final report = await StreamDiagnosticsService(client: client)
          .diagnose('https://media.example/channel.m3u8');

      expect(report.sourceStatus, 403);
      expect(report.possibleGeoRestriction, isTrue);
      expect(report.confirmedGeoRestriction, isFalse);
      expect(report.toDisplayString(), contains('posible restricción regional'));
      expect(report.toDisplayString(), contains('No se puede confirmar GeoIP'));
    });

    test('explicit provider message confirms a territorial restriction', () async {
      final client = MockClient((request) async =>
          http.Response('This stream is not available in your country', 403));
      addTearDown(client.close);
      final report = await StreamDiagnosticsService(client: client)
          .diagnose('https://media.example/channel.m3u8');

      expect(report.possibleGeoRestriction, isTrue);
      expect(report.confirmedGeoRestriction, isTrue);
      expect(report.toDisplayString(), contains('indicó expresamente'));
    });

    test('HLS diagnostic checks the manifest and first media segment', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/channel.m3u8') {
          return http.Response(
            '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nseg-1.ts\n',
            200,
            headers: const {'content-type': 'application/vnd.apple.mpegurl'},
          );
        }
        if (request.url.path == '/seg-1.ts') {
          return http.Response('segment bytes', 206);
        }
        return http.Response('', 404);
      });
      addTearDown(client.close);
      final report = await StreamDiagnosticsService(client: client)
          .diagnose('https://media.example/channel.m3u8');

      expect(report.sourceStatus, 200);
      expect(report.segmentStatus, 206);
      expect(report.toDisplayString(), contains('PRIMER RECURSO HLS: HTTP 206'));
    });

    test('HLS segment 403 is surfaced separately from a reachable manifest', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/channel.m3u8') {
          return http.Response('#EXTM3U\n#EXTINF:6,\nseg-1.ts\n', 200);
        }
        return http.Response('Forbidden', 403);
      });
      addTearDown(client.close);
      final report = await StreamDiagnosticsService(client: client)
          .diagnose('https://media.example/channel.m3u8');

      expect(report.sourceStatus, 200);
      expect(report.segmentStatus, 403);
      expect(report.possibleGeoRestriction, isTrue);
      expect(report.confirmedGeoRestriction, isFalse);
    });

    test('DASH protection markers are detected without attempting to bypass DRM', () async {
      final client = MockClient((request) async => http.Response(
        '<MPD><ContentProtection schemeIdUri="urn:uuid:widevine"></ContentProtection></MPD>',
        200,
      ));
      addTearDown(client.close);
      final report = await StreamDiagnosticsService(client: client)
          .diagnose('https://media.example/manifest.mpd');

      expect(report.drmDetected, isTrue);
      expect(report.title, contains('DRM'));
      expect(report.recommendation, contains('no se intenta eludir DRM'));
    });

    test('404 identifies an unavailable or withdrawn source', () async {
      final client = MockClient((request) async => http.Response('', 404));
      addTearDown(client.close);
      final report = await StreamDiagnosticsService(client: client)
          .diagnose('https://media.example/channel.m3u8');

      expect(report.sourceStatus, 404);
      expect(report.title, contains('Fuente no encontrada'));
    });
  });

  test('yb0 message explains that the code does not identify the root cause', () {
    final message = explainVideoPlayerError(
      Exception('PlatformException(VideoError yb0: Source error, null, null)'),
    );
    expect(message, contains('yb0 no identifica por sí solo la causa'));
    expect(message, contains('Detalle técnico'));
  });
}
