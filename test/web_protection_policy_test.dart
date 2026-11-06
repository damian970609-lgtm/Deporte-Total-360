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

    test('no bloquea la agenda ni reproductores HTTPS normales', () {
      expect(WebProtectionPolicy.isBlockedUrl('https://futbol-libre.cam/'), isFalse);
      expect(WebProtectionPolicy.isBlockedUrl('https://player.example.net/live/index.m3u8'), isFalse);
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
