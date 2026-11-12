import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/channel_proxy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChannelProxyEndpoint', () {
    test('acepta host:puerto como proxy HTTP', () {
      final proxy = ChannelProxyEndpoint.parse('192.0.2.10:8080');
      expect(proxy.scheme, 'http');
      expect(proxy.host, '192.0.2.10');
      expect(proxy.port, 8080);
    });

    test('acepta SOCKS5 y credenciales codificadas', () {
      final proxy = ChannelProxyEndpoint.parse(
        'socks5://usuario:clave%40segura@proxy.example:1080',
      );
      expect(proxy.scheme, 'socks5');
      expect(proxy.username, 'usuario');
      expect(proxy.password, 'clave@segura');
      expect(proxy.toPlatformArguments()['type'], 'socks5');
    });

    test('acepta proxy HTTP con autenticación', () {
      final proxy = ChannelProxyEndpoint.parse(
        'http://user:pass@proxy.example:3128',
      );
      expect(proxy.username, 'user');
      expect(proxy.password, 'pass');
      expect(proxy.port, 3128);
    });

    test('rechaza protocolos desconocidos y puertos inválidos', () {
      expect(
        () => ChannelProxyEndpoint.parse('ftp://proxy.example:21'),
        throwsFormatException,
      );
      expect(
        () => ChannelProxyEndpoint.parse('proxy.example:70000'),
        throwsFormatException,
      );
      expect(
        () => ChannelProxyEndpoint.parse('https://secure-proxy.example:443'),
        throwsFormatException,
      );
    });
  });

  test('prioriza en el siguiente intento el proxy que sí funcionó', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = ChannelProxyStore();
    final proxies = <ChannelProxyEndpoint>[
      ChannelProxyEndpoint.parse('first.example:8001'),
      ChannelProxyEndpoint.parse('second.example:8002'),
      ChannelProxyEndpoint.parse('third.example:8003'),
    ];
    await store.saveForChannel('channel-a', proxies);

    await store.moveToFront('channel-a', proxies[1].id);

    final saved = await store.loadForChannel('channel-a');
    expect(saved.first.id, proxies[1].id);
    expect(saved.skip(1).map((proxy) => proxy.id), <String>[
      proxies[0].id,
      proxies[2].id,
    ]);
  });

  test('guarda diez proxies por canal y no mezcla canales', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = ChannelProxyStore();
    final first = List<ChannelProxyEndpoint>.generate(
      10,
      (index) => ChannelProxyEndpoint.parse('proxy$index.example:${8000 + index}'),
    );
    await store.saveForChannel('channel-a', first);
    await store.saveForChannel(
      'channel-b',
      <ChannelProxyEndpoint>[ChannelProxyEndpoint.parse('socks5://other.example:1080')],
    );

    expect(await store.loadForChannel('channel-a'), hasLength(10));
    expect(await store.loadForChannel('channel-b'), hasLength(1));
    expect(await store.loadForChannel('channel-missing'), isEmpty);
    await expectLater(
      store.saveForChannel('channel-a', <ChannelProxyEndpoint>[
        ...first,
        ChannelProxyEndpoint.parse('extra.example:9999'),
      ]),
      throwsFormatException,
    );
  });
}
