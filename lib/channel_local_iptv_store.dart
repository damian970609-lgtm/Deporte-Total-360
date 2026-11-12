import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'channel_catalog_service.dart';

class ChannelLocalIptvSnapshot {
  const ChannelLocalIptvSnapshot({
    required this.email,
    required this.channels,
    required this.sources,
    required this.complete,
    required this.nextOffset,
  });

  final String email;
  final List<SportsChannel> channels;
  final List<ChannelPlaylistSource> sources;
  final bool complete;
  final int nextOffset;
}

/// Archivo privado de la aplicación para conservar el inventario IPTV completo.
/// No aplica el límite de 2.000 filas del snapshot ligero de SharedPreferences.
class ChannelLocalIptvStore {
  ChannelLocalIptvStore({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  String _normalizedEmail(String email) => email.trim().toLowerCase();

  File _fileFor(Directory directory, String email) {
    final encoded = base64Url
        .encode(utf8.encode(_normalizedEmail(email)))
        .replaceAll('=', '');
    return File('${directory.path}/dt360_iptv_catalog_$encoded.json');
  }

  Future<ChannelLocalIptvSnapshot?> load({required String email}) async {
    final normalizedEmail = _normalizedEmail(email);
    if (normalizedEmail.isEmpty) return null;

    try {
      final directory = await _directoryProvider();
      final file = _fileFor(directory, normalizedEmail);
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          _normalizedEmail((decoded['email'] ?? '').toString()) !=
              normalizedEmail) {
        return null;
      }

      final channels = <SportsChannel>[];
      final channelRows = decoded['channels'];
      if (channelRows is List) {
        // Se mantiene el orden y cada registro; no se deduplica por ID ni URL.
        for (final row in channelRows.whereType<Map>()) {
          try {
            channels.add(
              SportsChannel.fromJson(Map<String, dynamic>.from(row)),
            );
          } on FormatException {
            // Un registro inválido no debe impedir recuperar los demás.
          }
        }
      }

      final sources = <ChannelPlaylistSource>[];
      final sourceRows = decoded['sources'];
      if (sourceRows is List) {
        for (final row in sourceRows.whereType<Map>()) {
          try {
            sources.add(
              ChannelPlaylistSource.fromJson(
                Map<String, dynamic>.from(row),
              ),
            );
          } on FormatException {
            // Conserva las fuentes válidas.
          }
        }
      }

      return ChannelLocalIptvSnapshot(
        email: normalizedEmail,
        channels: List<SportsChannel>.unmodifiable(channels),
        sources: List<ChannelPlaylistSource>.unmodifiable(sources),
        complete: decoded['complete'] == true,
        nextOffset: (decoded['nextOffset'] as num?)?.toInt() ?? 0,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save({
    required String email,
    required List<SportsChannel> channels,
    required List<ChannelPlaylistSource> sources,
    required bool complete,
    required int nextOffset,
  }) async {
    final normalizedEmail = _normalizedEmail(email);
    if (normalizedEmail.isEmpty) {
      throw ArgumentError.value(email, 'email', 'La cuenta no puede estar vacía.');
    }

    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final destination = _fileFor(directory, normalizedEmail);
    final temporary = File('${destination.path}.tmp');
    final payload = <String, Object>{
      'version': 1,
      'email': normalizedEmail,
      'savedAt': DateTime.now().toIso8601String(),
      'complete': complete,
      'nextOffset': nextOffset < 0 ? 0 : nextOffset,
      'channels': channels.map((channel) => channel.toJson()).toList(),
      'sources': sources.map((source) => source.toJson()).toList(),
    };

    await temporary.writeAsString(jsonEncode(payload), flush: true);
    try {
      await temporary.rename(destination.path);
    } on FileSystemException {
      // Compatibilidad con plataformas que no reemplazan archivos existentes
      // al renombrar: elimina la versión anterior y completa el reemplazo.
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    }
  }
}
