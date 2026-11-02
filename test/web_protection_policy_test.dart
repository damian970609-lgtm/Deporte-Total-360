import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/web_protection_policy.dart';

void main() {
  group('WebProtectionPolicy', () {
    test('bloquea dominios publicitarios y sus subdominios', () {
      expect(WebProtectionPolicy.isBlockedHost('doubleclick.net'), isTrue);
      expect(WebProtectionPolicy.isBlockedHost('secure.pubmatic.com'), isTrue);
      expect(WebProtectionPolicy.isBlockedHost('cdn.juicyads.com'), isTrue);
      expect(WebProtectionPolicy.isBlockedHost('ads.trafficjunky.com'), isTrue);
    });

    test('no bloquea el sitio de agenda ni un host de vídeo genérico', () {
      expect(WebProtectionPolicy.isBlockedHost('futbol-libre.cam'), isFalse);
      expect(WebProtectionPolicy.isBlockedHost('player.example.net'), isFalse);
    });
  });
}
