import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/web_protection_policy.dart';

void main() {
  group('WebProtectionPolicy', () {
    test('bloquea redes publicitarias y subdominios', () {
      expect(WebProtectionPolicy.isBlockedHost('doubleclick.net'), isTrue);
      expect(WebProtectionPolicy.isBlockedHost('secure.pubmatic.com'), isTrue);
      expect(WebProtectionPolicy.isBlockedHost('pop.clickadu.com'), isTrue);
      expect(WebProtectionPolicy.isBlockedHost('ads.hilltopads.net'), isTrue);
    });

    test('bloquea dominios y rutas publicitarias explícitas', () {
      expect(WebProtectionPolicy.isBlockedUrl('https://juicyads.com/pop'), isTrue);
      expect(WebProtectionPolicy.isBlockedUrl('https://example.test/xxx/popup'), isTrue);
      expect(WebProtectionPolicy.isBlockedUrl('https://adultads.example.test/banner.js'), isTrue);
    });

    test('no bloquea servicios deportivos ni reproductores HTTPS normales', () {
      expect(WebProtectionPolicy.isBlockedUrl('https://worker.example/api/sportsapi/fixtures'), isFalse);
      expect(WebProtectionPolicy.isBlockedUrl('https://player.example.net/live/index.m3u8'), isFalse);
    });

    test('el reproductor solo permite navegación principal en su mismo dominio', () {
      expect(
        WebProtectionPolicy.allowsEmbeddedPlayerMainFrameNavigation(
          'https://futbol-libre.cam/partido/123',
          playerUrl: 'https://futbol-libre.cam/canal/espn',
        ),
        isTrue,
      );
      expect(
        WebProtectionPolicy.allowsEmbeddedPlayerMainFrameNavigation(
          'https://www.futbol-libre.cam/partido/123',
          playerUrl: 'https://futbol-libre.cam/canal/espn',
        ),
        isTrue,
      );
      expect(
        WebProtectionPolicy.allowsEmbeddedPlayerMainFrameNavigation(
          'https://basura.example/redirect',
          playerUrl: 'https://futbol-libre.cam/canal/espn',
        ),
        isFalse,
      );
      expect(
        WebProtectionPolicy.allowsEmbeddedPlayerMainFrameNavigation(
          'https://doubleclick.net/redirect',
          playerUrl: 'https://futbol-libre.cam/canal/espn',
        ),
        isFalse,
      );
      expect(
        WebProtectionPolicy.allowsEmbeddedPlayerMainFrameNavigation(
          'javascript:window.location="https://basura.example"',
          playerUrl: 'https://futbol-libre.cam/canal/espn',
        ),
        isFalse,
      );
    });

    test('el reproductor permite iframes de video externos sin abrir otra página', () {
      expect(
        WebProtectionPolicy.isBlockedUrl('https://player-cdn.example/embed/live'),
        isFalse,
      );
    });

    test('construye todos los bloqueadores en una lista modificable', () {
      final blockers = WebProtectionPolicy.buildContentBlockers();

      expect(
        blockers,
        hasLength(WebProtectionPolicy.blockedDomains.length + 1),
      );
      expect(() => blockers.add(blockers.last), returnsNormally);
    });

  });
}
