import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/channel_local_iptv_store.dart';

void main() {
  late Directory directory;
  late ChannelLocalIptvStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dt360-iptv-store-');
    store = ChannelLocalIptvStore(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  SportsChannel channel(int index) => SportsChannel(
        id: 'channel-$index',
        identifier: 'identifier-$index',
        name: 'Canal $index',
        url: 'https://media.example/channel-$index.m3u8',
        groupTitle: 'Deportes',
        isSports: index.isEven,
        visible: index.isOdd,
        language: index.isEven ? 'es' : 'en',
      );

  const sources = <ChannelPlaylistSource>[
    ChannelPlaylistSource(
      id: 'list-1',
      url: 'https://lists.example/one.m3u',
      label: 'Lista uno',
      status: 'imported',
      importedCount: 45,
    ),
    ChannelPlaylistSource(
      id: 'list-2',
      url: 'https://lists.example/two.m3u',
      label: 'Lista dos',
      status: 'queued',
    ),
  ];

  test('guarda más de 2.000 canales y conserva todos los registros', () async {
    final channels = List<SportsChannel>.generate(2505, channel);
    await store.save(
      email: 'admin@example.com',
      channels: channels,
      sources: sources,
      complete: true,
      nextOffset: channels.length,
    );

    final snapshot = await store.load(email: 'ADMIN@example.com');

    expect(snapshot, isNotNull);
    expect(snapshot!.complete, isTrue);
    expect(snapshot.nextOffset, 2505);
    expect(snapshot.channels, hasLength(2505));
    expect(snapshot.channels.first.name, 'Canal 0');
    expect(snapshot.channels.last.name, 'Canal 2504');
    expect(snapshot.sources.map((source) => source.id), ['list-1', 'list-2']);
  });

  test('no elimina filas repetidas ni modifica su orden', () async {
    final repeated = channel(1);
    final channels = <SportsChannel>[channel(0), repeated, repeated, channel(2)];

    await store.save(
      email: 'admin@example.com',
      channels: channels,
      sources: sources,
      complete: true,
      nextOffset: channels.length,
    );

    final snapshot = await store.load(email: 'admin@example.com');

    expect(snapshot!.channels, hasLength(4));
    expect(snapshot.channels.map((item) => item.id), [
      'channel-0',
      'channel-1',
      'channel-1',
      'channel-2',
    ]);
  });

  test('guarda cargas parciales con su cursor para poder reanudarlas', () async {
    final channels = List<SportsChannel>.generate(2000, channel);
    await store.save(
      email: 'admin@example.com',
      channels: channels,
      sources: sources,
      complete: false,
      nextOffset: 2000,
    );

    final snapshot = await store.load(email: 'admin@example.com');

    expect(snapshot!.complete, isFalse);
    expect(snapshot.nextOffset, 2000);
    expect(snapshot.channels, hasLength(2000));
  });

  test('aísla las copias locales de cuentas diferentes', () async {
    await store.save(
      email: 'one@example.com',
      channels: [channel(1)],
      sources: sources,
      complete: true,
      nextOffset: 1,
    );
    await store.save(
      email: 'two@example.com',
      channels: [channel(2)],
      sources: const [],
      complete: true,
      nextOffset: 1,
    );

    expect(
      (await store.load(email: 'one@example.com'))!.channels.single.id,
      'channel-1',
    );
    expect(
      (await store.load(email: 'two@example.com'))!.channels.single.id,
      'channel-2',
    );
  });

  test('devuelve null cuando todavía no hay una copia guardada', () async {
    expect(await store.load(email: 'missing@example.com'), isNull);
  });
}
