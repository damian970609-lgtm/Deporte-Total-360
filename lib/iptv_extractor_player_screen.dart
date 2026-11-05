import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const Color _studioBg = Color(0xFF030814);
const Color _studioPanel = Color(0xFF071326);
const Color _studioPanel2 = Color(0xFF0B1B31);
const Color _studioLine = Color(0xFF123D65);
const Color _studioCyan = Color(0xFF00E5FF);
const Color _studioGreen = Color(0xFF39FF9C);
const Color _studioPink = Color(0xFFFF28CF);
const Color _studioMuted = Color(0xFFA9BDD6);

const String defaultIptvStudioSportsUrl =
    'https://iptv-org.github.io/iptv/categories/sports.m3u';

const String _studioUrlsKey = 'dt360_secret_iptv_playlist_urls_v1';
const String _studioTextsKey = 'dt360_secret_iptv_playlist_texts_v1';
const String _studioFavoritesKey = 'dt360_secret_iptv_favorite_urls_v1';
const String _studioDefaultAddedKey = 'dt360_iptv_studio_default_added_v1';
const String _studioSportsChannelsKey = 'dt360_sports_selected_channels_v1';
const String _studioHiddenChannelsKey = 'dt360_hidden_sports_channel_ids_v1';
const String _studioHiddenChannelRecordsKey = 'dt360_hidden_sports_channel_records_v1';

bool _isHttpMediaUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

String _stableIptvHash(String value) {
  var hash = 2166136261;
  for (final unit in value.toLowerCase().trim().codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _normalizeIptvText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

class IptvExtractedChannel {
  const IptvExtractedChannel({
    required this.id,
    required this.name,
    required this.url,
    required this.source,
    this.group = '',
    this.logo = '',
    this.tvgId = '',
  });

  final String id;
  final String name;
  final String url;
  final String source;
  final String group;
  final String logo;
  final String tvgId;

  /// URI interna, estable y única para identificar este canal dentro de DT360.
  String get identificationUrl => 'dt360://channel/' +
      _stableIptvHash(id + '|' + _normalizeIptvText(name) + '|' + url.trim().toLowerCase());

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'url': url,
        'source': source,
        'group': group,
        'logo': logo,
        'tvgId': tvgId,
      };

  factory IptvExtractedChannel.fromJson(Map<String, dynamic> json) =>
      IptvExtractedChannel(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Canal').toString(),
        url: (json['url'] ?? '').toString(),
        source: (json['source'] ?? 'Lista importada').toString(),
        group: (json['group'] ?? '').toString(),
        logo: (json['logo'] ?? '').toString(),
        tvgId: (json['tvgId'] ?? '').toString(),
      );
}

/// Lista personal de canales escogidos para la pestaña pública.
/// No modifica ni elimina las fuentes M3U originales.
final ValueNotifier<int> iptvSportsCatalogVersion = ValueNotifier<int>(0);

Future<List<IptvExtractedChannel>> loadIptvStudioSportsChannels() async {
  final prefs = await SharedPreferences.getInstance();
  final records = prefs.getStringList(_studioSportsChannelsKey) ?? <String>[];
  final channels = <IptvExtractedChannel>[];
  final seen = <String>{};
  for (final record in records) {
    try {
      final decoded = jsonDecode(record);
      if (decoded is! Map) continue;
      final channel = IptvExtractedChannel.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (channel.id.isEmpty || !_isHttpMediaUrl(channel.url) ||
          !seen.add(channel.identificationUrl)) {
        continue;
      }
      channels.add(channel);
    } catch (_) {
      // Un registro dañado no impide recuperar los demás canales.
    }
  }
  return channels;
}

Future<void> saveIptvStudioSportsChannels(
  Iterable<IptvExtractedChannel> channels,
) async {
  final unique = <String, IptvExtractedChannel>{};
  for (final channel in channels) {
    if (channel.id.isNotEmpty && _isHttpMediaUrl(channel.url)) {
      unique[channel.identificationUrl] = channel;
    }
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    _studioSportsChannelsKey,
    unique.values.map((channel) => jsonEncode(channel.toJson())).toList(),
  );
  iptvSportsCatalogVersion.value++;
}

Future<void> addIptvStudioSportsChannel(
  IptvExtractedChannel channel,
) async {
  final channels = await loadIptvStudioSportsChannels();
  channels.removeWhere((item) => item.identificationUrl == channel.identificationUrl);
  channels.add(channel);
  await saveIptvStudioSportsChannels(channels);
}

Future<void> removeIptvStudioSportsChannel(String identificationUrl) async {
  final channels = await loadIptvStudioSportsChannels();
  channels.removeWhere((channel) => channel.identificationUrl == identificationUrl);
  await saveIptvStudioSportsChannels(channels);
}

/// Fuentes compartidas por el catálogo público y el menú secreto.
Future<List<String>> loadIptvStudioPlaylistUrls() async {
  final prefs = await SharedPreferences.getInstance();
  var urls = prefs.getStringList(_studioUrlsKey) ?? <String>[];
  if (!urls.contains(defaultIptvStudioSportsUrl)) {
    urls = <String>[
      defaultIptvStudioSportsUrl,
      ...urls.where((url) => url.trim() != defaultIptvStudioSportsUrl),
    ];
    await prefs.setStringList(_studioUrlsKey, urls);
    await prefs.setBool(_studioDefaultAddedKey, true);
  }
  return urls
      .map((url) => url.trim())
      .where(_isHttpMediaUrl)
      .toSet()
      .toList(growable: true);
}

Future<List<String>> loadIptvStudioPlaylistTexts() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_studioTextsKey) ?? <String>[];
}

Future<void> addIptvStudioPlaylistUrls(Iterable<String> values) async {
  final incoming = values.map((value) => value.trim()).where((value) => value.isNotEmpty);
  if (incoming.isEmpty || !incoming.every(_isHttpMediaUrl)) {
    throw const FormatException('Introduce URLs HTTP/HTTPS válidas.');
  }
  final urls = await loadIptvStudioPlaylistUrls();
  for (final url in incoming) {
    if (!urls.contains(url)) urls.add(url);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_studioUrlsKey, urls);
}

Future<Set<String>> loadIptvStudioHiddenChannelIds() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_studioHiddenChannelsKey) ?? <String>[]).toSet();
}

Future<List<IptvExtractedChannel>> loadIptvStudioHiddenChannels() async {
  final prefs = await SharedPreferences.getInstance();
  final records =
      prefs.getStringList(_studioHiddenChannelRecordsKey) ?? <String>[];
  final channels = <IptvExtractedChannel>[];
  for (final record in records) {
    try {
      final decoded = jsonDecode(record);
      if (decoded is! Map) continue;
      final channel = IptvExtractedChannel.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (channel.id.isNotEmpty && _isHttpMediaUrl(channel.url)) {
        channels.add(channel);
      }
    } catch (_) {
      // Se omite un registro dañado y se recuperan los demás.
    }
  }
  return channels;
}

Future<void> setIptvStudioChannelHidden(
  String identificationUrl,
  bool hidden, {
  IptvExtractedChannel? channel,
}) async {
  final id = identificationUrl.trim();
  if (id.isEmpty) return;
  final ids = await loadIptvStudioHiddenChannelIds();
  final records = await loadIptvStudioHiddenChannels();
  if (hidden) {
    ids.add(id);
    if (channel != null) {
      records.removeWhere((item) => item.identificationUrl == id);
      records.add(channel);
    }
  } else {
    ids.remove(id);
    records.removeWhere((item) => item.identificationUrl == id);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_studioHiddenChannelsKey, ids.toList()..sort());
  await prefs.setStringList(
    _studioHiddenChannelRecordsKey,
    records.map((item) => jsonEncode(item.toJson())).toList(),
  );
}


/// Parser separado del servicio de agenda: acepta señales HTTP(S) directas
/// aunque no tengan una extensión reconocible en la URL.
List<IptvExtractedChannel> parseIptvStudioM3u(
  String body, {
  String sourceUrl = '',
}) {
  final text = body.replaceFirst('\uFEFF', '').trim();
  if (!text.toUpperCase().startsWith('#EXTM3U')) {
    throw const FormatException(
      'La respuesta no es una lista M3U válida: falta #EXTM3U.',
    );
  }
  if (utf8.encode(text).length > 12 * 1024 * 1024) {
    throw const FormatException('La lista supera 12 MB.');
  }

  final baseUri = Uri.tryParse(sourceUrl);
  final result = <IptvExtractedChannel>[];
  Map<String, String>? attributes;
  var pendingName = '';

  for (final rawLine in text.replaceAll('\r', '').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.toUpperCase().startsWith('#EXTINF:')) {
      final comma = line.indexOf(',');
      final metadata = comma >= 0 ? line.substring(0, comma) : line;
      pendingName = comma >= 0 ? line.substring(comma + 1).trim() : '';
      final found = <String, String>{};
      final pattern = RegExp(
        r"""([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s,]+))""",
      );
      for (final match in pattern.allMatches(metadata)) {
        final key = match.group(1);
        if (key == null || key.isEmpty) continue;
        found[key.toLowerCase()] =
            (match.group(2) ?? match.group(3) ?? match.group(4) ?? '').trim();
      }
      attributes = found;
      continue;
    }

    if (line.startsWith('#') || attributes == null) continue;

    var streamUri = Uri.tryParse(line);
    if (streamUri != null && !streamUri.hasScheme && baseUri != null) {
      streamUri = baseUri.resolveUri(streamUri);
    }
    final streamUrl = streamUri?.toString() ?? '';
    final path = streamUri?.path.toLowerCase() ?? '';
    final isNestedPlaylist = path.endsWith('.m3u') && !path.endsWith('.m3u8');

    if (_isHttpMediaUrl(streamUrl) && !isNestedPlaylist) {
      final group = attributes['group-title'] ?? '';
      final tvgId = attributes['tvg-id'] ?? '';
      final tvgName = attributes['tvg-name'] ?? '';
      final name = pendingName.isNotEmpty
          ? pendingName
          : (tvgName.isNotEmpty ? tvgName : (tvgId.isNotEmpty ? tvgId : 'Canal'));
      final identity = tvgId.isNotEmpty
          ? 'id:' + tvgId.toLowerCase()
          : 'name:' + _normalizeIptvText(name) +
              '|group:' + _normalizeIptvText(group);

      result.add(IptvExtractedChannel(
        id: 'dt360-' + _stableIptvHash(identity),
        name: name,
        url: streamUrl,
        source: sourceUrl.isEmpty ? 'Lista importada' : sourceUrl,
        group: group,
        logo: attributes['tvg-logo'] ?? '',
        tvgId: tvgId,
      ));
    }

    attributes = null;
    pendingName = '';
  }

  if (result.isEmpty) {
    throw const FormatException(
      'La lista no contiene direcciones de canales HTTP/HTTPS directas.',
    );
  }
  return result;
}


/// Lee las mismas listas que administra el menú secreto de IPTV Extractor 360.
/// La pantalla pública consume esta biblioteca sin crear una segunda lista.
Future<List<IptvExtractedChannel>> loadSavedIptvStudioChannels({
  http.Client? httpClient,
  bool parseInBackground = true,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final urls = prefs.getStringList(_studioUrlsKey) ?? <String>[];
  final texts = prefs.getStringList(_studioTextsKey) ?? <String>[];
  final ownsClient = httpClient == null;
  final client = httpClient ?? http.Client();

  Future<List<IptvExtractedChannel>> loadRemote(String url) async {
    try {
      final response = await client.get(
        Uri.parse(url),
        headers: const <String, String>{
          'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, text/plain, */*',
          'User-Agent': 'DeporteTotal360-IPTV/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <IptvExtractedChannel>[];
      }
      if (response.bodyBytes.length > 12 * 1024 * 1024) {
        return <IptvExtractedChannel>[];
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (parseInBackground) {
        return await Isolate.run(
          () => parseIptvStudioM3u(body, sourceUrl: url),
        );
      }
      return parseIptvStudioM3u(body, sourceUrl: url);
    } catch (_) {
      return <IptvExtractedChannel>[];
    }
  }

  try {
    final remoteResults = await Future.wait(
      urls.where(_isHttpMediaUrl).map(loadRemote),
    );
    final channels = <IptvExtractedChannel>[];
    for (final result in remoteResults) {
      channels.addAll(result);
    }
    for (var index = 0; index < texts.length; index++) {
      try {
        channels.addAll(
          parseIptvStudioM3u(
            texts[index],
            sourceUrl: 'Importada #' + (index + 1).toString(),
          ),
        );
      } catch (_) {
        // Una lista local dañada no impide mostrar el resto de fuentes.
      }
    }
    return channels;
  } finally {
    if (ownsClient) client.close();
  }
}

Future<Set<String>> loadIptvStudioFavoriteIds() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_studioFavoritesKey) ?? <String>[]).toSet();
}

Future<void> saveIptvStudioFavoriteIds(Iterable<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_studioFavoritesKey, ids.toSet().toList());
}

class _IptvStudioChannelGroup {
  const _IptvStudioChannelGroup(this.channels);
  final List<IptvExtractedChannel> channels;
  IptvExtractedChannel get primary => channels.first;
}

/// Se actualiza al elegir un canal en el menú secreto; MainShell abre la pestaña pública.
final ValueNotifier<IptvExtractedChannel?> iptvSelectedSportsChannel =
    ValueNotifier<IptvExtractedChannel?>(null);

class IptvExtractorPlayerScreen extends StatefulWidget {
  const IptvExtractorPlayerScreen({
    super.key,
    this.httpClient,
    this.parseInBackground = true,
  });

  final http.Client? httpClient;
  final bool parseInBackground;

  @override
  State<IptvExtractorPlayerScreen> createState() =>
      _IptvExtractorPlayerScreenState();
}

class _IptvExtractorPlayerScreenState
    extends State<IptvExtractorPlayerScreen> {
  late final http.Client _client;
  late final bool _ownsClient;
  final TextEditingController _searchController = TextEditingController();

  List<String> _playlistUrls = <String>[];
  List<String> _playlistTexts = <String>[];
  final Set<String> _favoriteIds = <String>{};
  final Set<String> _hiddenChannelIds = <String>{};
  final List<IptvExtractedChannel> _rawChannels = <IptvExtractedChannel>[];
  List<_IptvStudioChannelGroup> _groups = <_IptvStudioChannelGroup>[];
  final Map<String, String> _sourceStatuses = <String, String>{};

  bool _initializing = true;
  bool _refreshing = false;
  int _generation = 0;
  String _query = '';
  String _selectedGroup = 'Todos';
  String? _loadMessage;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.httpClient == null;
    _client = widget.httpClient ?? http.Client();
    _searchController.addListener(_updateSearch);
    _loadSavedLibrary();
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearch);
    _searchController.dispose();
    if (_ownsClient) _client.close();
    super.dispose();
  }

  void _updateSearch() {
    if (mounted) setState(() => _query = _searchController.text.trim());
  }

  Future<void> _loadSavedLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var urls = prefs.getStringList(_studioUrlsKey) ?? <String>[];
      final texts = prefs.getStringList(_studioTextsKey) ?? <String>[];
      final hiddenChannelIds = await loadIptvStudioHiddenChannelIds();
      if (!(prefs.getBool(_studioDefaultAddedKey) ?? false)) {
        urls = <String>[
          defaultIptvStudioSportsUrl,
          ...urls.where((url) => url.trim() != defaultIptvStudioSportsUrl),
        ];
        await prefs.setStringList(_studioUrlsKey, urls);
        await prefs.setBool(_studioDefaultAddedKey, true);
      }
      if (!mounted) return;
      setState(() {
        _playlistUrls = urls.where(_isHttpMediaUrl).toList(growable: true);
        _playlistTexts = texts;
        _favoriteIds
          ..clear()
          ..addAll(prefs.getStringList(_studioFavoritesKey) ?? <String>[]);
        _hiddenChannelIds
          ..clear()
          ..addAll(hiddenChannelIds);
        _initializing = false;
      });
      await _refreshLibrary();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _loadMessage = 'No se pudo abrir la biblioteca: ' + error.toString();
      });
    }
  }

  Future<void> _persistLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_studioUrlsKey, _playlistUrls);
    await prefs.setStringList(_studioTextsKey, _playlistTexts);
    await prefs.setStringList(_studioFavoritesKey, _favoriteIds.toList());
  }

  Future<List<IptvExtractedChannel>> _parse(
    String text, {
    required String source,
  }) async {
    if (widget.parseInBackground) {
      return Isolate.run(() => parseIptvStudioM3u(text, sourceUrl: source));
    }
    return parseIptvStudioM3u(text, sourceUrl: source);
  }

  Future<void> _refreshLibrary() async {
    final generation = ++_generation;
    final hiddenChannelIds = await loadIptvStudioHiddenChannelIds();
    final hiddenChannels = await loadIptvStudioHiddenChannels();
    if (!mounted || generation != _generation) return;
    setState(() {
      _hiddenChannelIds
        ..clear()
        ..addAll(hiddenChannelIds);
      _refreshing = true;
      _rawChannels
        ..clear()
        ..addAll(hiddenChannels);
      _rebuildGroups();
      _groups = <_IptvStudioChannelGroup>[];
      _sourceStatuses.clear();
      _loadMessage = null;
      _selectedGroup = 'Todos';
    });

    final jobs = <Future<void>>[];
    for (final url in List<String>.of(_playlistUrls)) {
      jobs.add(_loadRemotePlaylist(url, generation));
    }
    for (var index = 0; index < _playlistTexts.length; index++) {
      jobs.add(_loadLocalPlaylist(index, _playlistTexts[index], generation));
    }

    if (jobs.isEmpty) {
      if (mounted && generation == _generation) {
        setState(() {
          _refreshing = false;
          _loadMessage = 'Aún no hay listas. Agrega una URL M3U o importa un archivo.';
        });
      }
      return;
    }

    await Future.wait(jobs);
    if (!mounted || generation != _generation) return;
    setState(() {
      _refreshing = false;
      if (_rawChannels.isEmpty && _sourceStatuses.isEmpty) {
        _loadMessage = 'No se recibió ninguna lista. Comprueba la conexión o importa otra fuente.';
      } else if (_rawChannels.isEmpty) {
        _loadMessage = 'Las fuentes respondieron, pero no entregaron canales directos HTTP/HTTPS.';
      }
    });
  }

  Future<void> _loadRemotePlaylist(String url, int generation) async {
    if (mounted && generation == _generation) {
      setState(() => _sourceStatuses[url] = 'Cargando…');
    }
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: const <String, String>{
          'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, text/plain, */*',
          'User-Agent': 'DeporteTotal360-IPTV/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ' + response.statusCode.toString());
      }
      if (response.bodyBytes.length > 12 * 1024 * 1024) {
        throw const FormatException('La lista supera 12 MB.');
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final channels = await _parse(body, source: url);
      if (!mounted || generation != _generation) return;
      setState(() {
        _rawChannels.addAll(channels);
        _rebuildGroups();
        _sourceStatuses[url] = channels.length.toString() + ' canales';
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _sourceStatuses[url] = 'Error: ' + error.toString());
    }
  }

  Future<void> _loadLocalPlaylist(
    int index,
    String text,
    int generation,
  ) async {
    final source = 'Importada #' + (index + 1).toString();
    if (mounted && generation == _generation) {
      setState(() => _sourceStatuses[source] = 'Leyendo…');
    }
    try {
      final channels = await _parse(text, source: source);
      if (!mounted || generation != _generation) return;
      setState(() {
        _rawChannels.addAll(channels);
        _rebuildGroups();
        _sourceStatuses[source] = channels.length.toString() + ' canales';
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _sourceStatuses[source] = 'Error: ' + error.toString());
    }
  }

  void _rebuildGroups() {
    final grouped = <String, List<IptvExtractedChannel>>{};
    for (final channel in _rawChannels) {
      final key = channel.tvgId.trim().isNotEmpty
          ? 'id:' + channel.tvgId.trim().toLowerCase() +
              '|name:' + _normalizeIptvText(channel.name)
          : 'name:' + _normalizeIptvText(channel.name) +
              '|group:' + _normalizeIptvText(channel.group);
      final values = grouped.putIfAbsent(key, () => <IptvExtractedChannel>[]);
      if (!values.any((item) => item.url == channel.url)) values.add(channel);
    }
    _groups = grouped.values
        .map((items) => _IptvStudioChannelGroup(
              List<IptvExtractedChannel>.unmodifiable(items),
            ))
        .toList(growable: false)
      ..sort((a, b) => a.primary.name.toLowerCase().compareTo(
            b.primary.name.toLowerCase(),
          ));
  }

  List<String> get _availableGroups {
    final values = _groups
        .map((entry) => entry.primary.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return <String>['Todos', ...values];
  }

  List<_IptvStudioChannelGroup> get _filteredGroups {
    final query = _normalizeIptvText(_query);
    return _groups.where((entry) {
      if (_selectedGroup != 'Todos' &&
          entry.channels.every((channel) => channel.group != _selectedGroup)) {
        return false;
      }
      if (query.isEmpty) return true;
      return entry.channels.any((channel) =>
          _normalizeIptvText(
            channel.name + ' ' + channel.group + ' ' + channel.tvgId,
          ).contains(query));
    }).toList(growable: false);
  }

  Future<void> _addPlaylistUrls(String raw) async {
    final incoming = raw
        .split(RegExp(r'[\r\n;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (incoming.isEmpty || !incoming.every(_isHttpMediaUrl)) {
      _showMessage('Introduce URLs HTTP/HTTPS válidas, una por línea.');
      return;
    }
    final added = incoming.where((url) => !_playlistUrls.contains(url)).toList();
    if (added.isEmpty) {
      _showMessage('Esas listas ya están guardadas.');
      return;
    }
    setState(() => _playlistUrls.addAll(added));
    try {
      await _persistLibrary();
      await _refreshLibrary();
      _showMessage(added.length.toString() + ' lista(s) agregada(s).');
    } catch (error) {
      _showMessage('No se pudieron guardar las listas: ' + error.toString());
    }
  }

  Future<void> _showAddUrlDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _studioPanel,
        title: const Text(
          'Agregar listas IPTV',
          style: TextStyle(color: _studioCyan, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 7,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Una URL M3U/M3U8 por línea',
              hintText: 'https://servidor/lista.m3u',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) await _addPlaylistUrls(result);
  }

  Future<void> _importM3uText(String raw, {String source = 'Lista pegada'}) async {
    final text = raw.replaceFirst('\uFEFF', '').trim();
    try {
      final parsed = await _parse(text, source: source);
      if (!mounted) return;
      if (!_playlistTexts.contains(text)) _playlistTexts.add(text);
      await _persistLibrary();
      await _refreshLibrary();
      _showMessage('Importada: ' + parsed.length.toString() + ' canales detectados.');
    } catch (error) {
      _showMessage('No se pudo importar: ' + error.toString());
    }
  }

  Future<void> _showPasteDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _studioPanel,
        title: const Text(
          'Pegar contenido M3U',
          style: TextStyle(color: _studioCyan, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 6,
            maxLines: 12,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              hintText: 'El contenido debe comenzar con #EXTM3U',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('IMPORTAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) await _importM3uText(result);
  }

  Future<void> _pickPlaylistFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['m3u', 'm3u8', 'txt'],
      );
      if (!mounted || files.isEmpty) return;
      var filesImported = 0;
      var channelsFound = 0;
      final errors = <String>[];
      for (final file in files) {
        try {
          final reportedLength = await file.length();
          if (reportedLength != null && reportedLength > 12 * 1024 * 1024) {
            throw const FormatException('El archivo supera 12 MB.');
          }
          final bytes = await file.readAsBytes();
          if (bytes.length > 12 * 1024 * 1024) {
            throw const FormatException('El archivo supera 12 MB.');
          }
          final text = utf8.decode(bytes, allowMalformed: true).trim();
          final parsed = await _parse(text, source: file.name);
          if (!_playlistTexts.contains(text)) _playlistTexts.add(text);
          filesImported++;
          channelsFound += parsed.length;
        } catch (error) {
          errors.add(file.name + ': ' + error.toString());
        }
      }
      if (filesImported == 0) {
        _showMessage(errors.isEmpty ? 'No seleccionaste archivos.' : errors.take(2).join(' | '));
        return;
      }
      await _persistLibrary();
      await _refreshLibrary();
      _showMessage(
        filesImported.toString() + ' archivo(s), ' +
            channelsFound.toString() + ' canales.' +
            (errors.isEmpty ? '' : ' Omitidos: ' + errors.take(2).join(' | ')),
      );
    } catch (error) {
      _showMessage('No se pudo abrir el selector: ' + error.toString());
    }
  }

  Future<void> _importClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _showMessage('Copia primero una URL M3U o el contenido de una lista.');
    } else if (text.toUpperCase().startsWith('#EXTM3U')) {
      await _importM3uText(text);
    } else {
      await _addPlaylistUrls(text);
    }
  }

  Future<void> _removePlaylistUrl(String url) async {
    setState(() => _playlistUrls.remove(url));
    await _persistLibrary();
    await _refreshLibrary();
  }

  Future<void> _removePlaylistText(int index) async {
    if (index < 0 || index >= _playlistTexts.length) return;
    setState(() => _playlistTexts.removeAt(index));
    await _persistLibrary();
    await _refreshLibrary();
  }

  Future<void> _showSavedSources() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _studioPanel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * .75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'MIS LISTAS GUARDADAS',
                    style: TextStyle(color: _studioCyan, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        for (final url in _playlistUrls)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.link, color: _studioGreen),
                            title: Text(
                              Uri.tryParse(url)?.host ?? url,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _sourceStatuses[url] ?? url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _studioMuted, fontSize: 11),
                            ),
                            trailing: IconButton(
                              tooltip: 'Eliminar lista',
                              onPressed: () async {
                                await _removePlaylistUrl(url);
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                              icon: const Icon(Icons.delete_outline, color: _studioPink),
                            ),
                          ),
                        for (var index = 0; index < _playlistTexts.length; index++)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.file_present, color: _studioPink),
                            title: Text(
                              'Lista importada #' + (index + 1).toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _sourceStatuses['Importada #' + (index + 1).toString()] ??
                                  'Contenido local',
                              style: const TextStyle(color: _studioMuted, fontSize: 11),
                            ),
                            trailing: IconButton(
                              tooltip: 'Eliminar lista',
                              onPressed: () async {
                                await _removePlaylistText(index);
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                              icon: const Icon(Icons.delete_outline, color: _studioPink),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('CERRAR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyChannelUrl(IptvExtractedChannel channel) async {
    await Clipboard.setData(ClipboardData(text: channel.url));
    _showMessage('URL directa copiada: ' + channel.name);
  }

  Future<void> _copyChannelIdentifier(IptvExtractedChannel channel) async {
    await Clipboard.setData(ClipboardData(text: channel.identificationUrl));
    _showMessage('Identificador copiado: ' + channel.identificationUrl);
  }

  Future<void> _toggleChannelVisibility(_IptvStudioChannelGroup entry) async {
    final channel = entry.primary;
    final hidden = !_hiddenChannelIds.contains(channel.identificationUrl);
    setState(() {
      if (hidden) {
        _hiddenChannelIds.add(channel.identificationUrl);
      } else {
        _hiddenChannelIds.remove(channel.identificationUrl);
      }
    });
    try {
      await setIptvStudioChannelHidden(
        channel.identificationUrl,
        hidden,
        channel: channel,
      );
      _showMessage(hidden
          ? channel.name + ' quedó oculto en Canales deportivos.'
          : channel.name + ' volvió a Canales deportivos.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (hidden) {
          _hiddenChannelIds.remove(channel.identificationUrl);
        } else {
          _hiddenChannelIds.add(channel.identificationUrl);
        }
      });
      _showMessage('No se pudo cambiar la visibilidad: ' + error.toString());
    }
  }

  Future<void> _toggleFavorite(_IptvStudioChannelGroup entry) async {
    final id = entry.primary.id;
    setState(() {
      if (!_favoriteIds.add(id)) _favoriteIds.remove(id);
    });
    await _persistLibrary();
  }

  bool _isFavorite(_IptvStudioChannelGroup entry) =>
      _favoriteIds.contains(entry.primary.id);

  void _openChannel(_IptvStudioChannelGroup entry) {
    iptvSelectedSportsChannel.value = entry.primary;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildChannelCard(_IptvStudioChannelGroup entry) {
    final channel = entry.primary;
    final favorite = _isFavorite(entry);
    final hidden = _hiddenChannelIds.contains(channel.identificationUrl);
    final metadata = <String>[
      if (channel.group.isNotEmpty) channel.group,
      if (entry.channels.length > 1) entry.channels.length.toString() + ' fuentes',
    ].join(' · ');

    return Material(
      color: _studioPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: _studioLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 43,
            height: 43,
            child: channel.logo.isNotEmpty && _isHttpMediaUrl(channel.logo)
                ? Image.network(
                    channel.logo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.live_tv, color: _studioCyan),
                  )
                : const Icon(Icons.live_tv, color: _studioCyan),
          ),
        ),
        title: Text(
          channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          (metadata.isEmpty ? 'Canal directo' : metadata) +
              (hidden ? ' · OCULTO EN CANALES DEPORTIVOS' : ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _studioMuted, fontSize: 10),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Acciones del canal',
          icon: const Icon(Icons.more_vert, color: _studioCyan),
          onSelected: (action) {
            if (action == 'copy') {
              _copyChannelUrl(channel);
            } else if (action == 'favorite') {
              _toggleFavorite(entry);
            } else if (action == 'toggleVisibility') {
              _toggleChannelVisibility(entry);
            } else if (action == 'copyIdentifier') {
              _copyChannelIdentifier(channel);
            } else if (action == 'sources') {
              _showAlternatives(entry);
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'copy',
              child: Text('Copiar URL directa'),
            ),
            PopupMenuItem<String>(
              value: 'copyIdentifier',
              child: const Text('Copiar URL identificadora'),
            ),
            PopupMenuItem<String>(
              value: 'toggleVisibility',
              child: Text(hidden
                  ? 'Mostrar en Canales deportivos'
                  : 'Ocultar en Canales deportivos'),
            ),
            PopupMenuItem<String>(
              value: 'favorite',
              child: Text(favorite ? 'Quitar de favoritos' : 'Agregar a favoritos'),
            ),
            if (entry.channels.length > 1)
              const PopupMenuItem<String>(
                value: 'sources',
                child: Text('Elegir fuente alternativa'),
              ),
          ],
        ),
        onTap: () => _openChannel(entry),
      ),
    );
  }

  Future<void> _showAlternatives(_IptvStudioChannelGroup entry) async {
    final selected = await showModalBottomSheet<IptvExtractedChannel>(
      context: context,
      backgroundColor: _studioPanel,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'FUENTES DE ' + entry.primary.name,
                style: const TextStyle(color: _studioCyan, fontWeight: FontWeight.w900),
              ),
            ),
            for (final channel in entry.channels)
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: _studioGreen),
                title: Text(channel.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  Uri.tryParse(channel.source)?.host ?? channel.source,
                  style: const TextStyle(color: _studioMuted, fontSize: 10),
                ),
                trailing: IconButton(
                  tooltip: 'Copiar URL',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: channel.url));
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('URL copiada')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, color: _studioCyan),
                ),
                onTap: () => Navigator.pop(sheetContext, channel),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      final alternatives = entry.channels
          .where((channel) => channel.url != selected.url)
          .toList(growable: false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _IptvStudioPlayerScreen(
            channel: selected,
            alternatives: alternatives,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGroups;
    final groupOptions = _availableGroups;
    final totalSources = _playlistUrls.length + _playlistTexts.length;

    return Scaffold(
      backgroundColor: _studioBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'IPTV EXTRACTOR 360',
          style: TextStyle(
            color: _studioCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mis listas guardadas',
            onPressed: _showSavedSources,
            icon: const Icon(Icons.playlist_play, color: _studioGreen),
          ),
          IconButton(
            tooltip: 'Actualizar listas',
            onPressed: _refreshing ? null : _refreshLibrary,
            icon: Icon(
              Icons.refresh,
              color: _refreshing ? _studioMuted : _studioCyan,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF0B2440),
                    Color(0xFF10142E),
                    Color(0xFF1D0D31),
                  ],
                ),
                border: Border(bottom: BorderSide(color: _studioLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'IMPORTA, UNE, EXTRAE Y REPRODUCE',
                    style: TextStyle(
                      color: _studioGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Módulo independiente de listas M3U/M3U8. Cada fuente muestra su resultado y los canales aparecen conforme terminan de cargar.',
                    style: TextStyle(color: _studioMuted, fontSize: 11, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _showAddUrlDialog,
                        icon: const Icon(Icons.add_link),
                        label: const Text('AÑADIR URL'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _studioCyan,
                          foregroundColor: _studioBg,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickPlaylistFiles,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('ARCHIVOS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _studioPink,
                          side: const BorderSide(color: _studioPink),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showPasteDialog,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('PEGAR M3U'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _studioGreen,
                          side: const BorderSide(color: _studioGreen),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importClipboard,
                        icon: const Icon(Icons.content_paste),
                        label: const Text('PORTAPAPELES'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _studioLine),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_refreshing || _initializing)
              const LinearProgressIndicator(
                minHeight: 2,
                color: _studioCyan,
                backgroundColor: _studioLine,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar canal, liga, deporte o grupo…',
                      prefixIcon: Icon(Icons.search, color: _studioCyan),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _groups.length.toString() + ' canales · ' +
                              totalSources.toString() + ' listas',
                          style: const TextStyle(
                            color: _studioGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: groupOptions.contains(_selectedGroup)
                              ? _selectedGroup
                              : 'Todos',
                          isDense: true,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                          ),
                          items: groupOptions
                              .map((group) => DropdownMenuItem<String>(
                                    value: group,
                                    child: Text(
                                      group,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedGroup = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_loadMessage != null && _groups.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _studioPanel2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _studioPink.withAlpha(150)),
                  ),
                  child: Text(
                    _loadMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
                  ),
                ),
              ),
            if (_sourceStatuses.isNotEmpty && _groups.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _sourceStatuses.entries
                        .where((entry) => entry.value.startsWith('Error'))
                        .take(3)
                        .map((entry) => (Uri.tryParse(entry.key)?.host ?? entry.key) +
                            ': ' + entry.value)
                        .join('\n'),
                    style: const TextStyle(color: _studioMuted, fontSize: 10, height: 1.4),
                  ),
                ),
              ),
            Expanded(
              child: _groups.isEmpty
                  ? Center(
                      child: _initializing
                          ? const CircularProgressIndicator(color: _studioCyan)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.playlist_remove, color: _studioMuted, size: 42),
                                const SizedBox(height: 9),
                                const Text(
                                  'Todavía no hay canales cargados',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Agrega una lista propia o revisa el resultado de cada fuente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _studioMuted, fontSize: 11),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _refreshing ? null : _refreshLibrary,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('REINTENTAR'),
                                ),
                              ],
                            ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay canales que coincidan con la búsqueda.',
                            style: TextStyle(color: _studioMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 7),
                          itemBuilder: (_, index) => _buildChannelCard(filtered[index]),
                        ),
            ),
            if (_refreshing && _groups.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  'Actualizando fuentes; los canales ya cargados siguen disponibles.',
                  style: TextStyle(color: _studioMuted, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IptvStudioPlayerScreen extends StatefulWidget {
  const _IptvStudioPlayerScreen({
    required this.channel,
    this.alternatives = const <IptvExtractedChannel>[],
  });

  final IptvExtractedChannel channel;
  final List<IptvExtractedChannel> alternatives;

  @override
  State<_IptvStudioPlayerScreen> createState() => _IptvStudioPlayerScreenState();
}

class _IptvStudioPlayerScreenState extends State<_IptvStudioPlayerScreen> {
  VideoPlayerController? _controller;
  List<VideoAudioTrack> _audioTracks = <VideoAudioTrack>[];
  List<VideoTrack> _videoTracks = <VideoTrack>[];
  bool _loading = true;
  bool _fullscreen = false;
  String? _error;
  int _activeSourceIndex = 0;

  List<IptvExtractedChannel> get _sources =>
      <IptvExtractedChannel>[widget.channel, ...widget.alternatives];

  @override
  void initState() {
    super.initState();
    _startAt(0);
  }

  @override
  void dispose() {
    _controller?.removeListener(_controllerChanged);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  VideoFormat _formatHint(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return VideoFormat.hls;
    if (path.endsWith('.mpd')) return VideoFormat.dash;
    return VideoFormat.other;
  }

  Future<void> _startAt(int index) async {
    if (index < 0 || index >= _sources.length) return;
    final old = _controller;
    old?.removeListener(_controllerChanged);
    _controller = null;
    await old?.dispose();
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _activeSourceIndex = index;
      _audioTracks = <VideoAudioTrack>[];
      _videoTracks = <VideoTrack>[];
    });

    final candidate = _sources[index];
    VideoPlayerController? next;
    try {
      next = VideoPlayerController.networkUrl(
        Uri.parse(candidate.url),
        formatHint: _formatHint(candidate.url),
        httpHeaders: const <String, String>{
          'User-Agent': 'DeporteTotal360-IPTV/1.0',
        },
      );
      await next.initialize().timeout(const Duration(seconds: 22));

      if (next.isAudioTrackSupportAvailable()) {
        _audioTracks = await next.getAudioTracks();
      }
      if (next.isVideoTrackSupportAvailable()) {
        _videoTracks = await next.getVideoTracks();
      }

      if (!mounted) {
        await next.dispose();
        return;
      }
      _controller = next;
      next.addListener(_controllerChanged);
      await next.play();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      await next?.dispose();
      if (!mounted) return;
      if (index + 1 < _sources.length) {
        await _startAt(index + 1);
      } else {
        setState(() {
          _loading = false;
          _error = 'No se pudo iniciar la señal. Comprueba que sea una transmisión directa, esté activa y permita reproducción en tu región. Detalle: ' +
              error.toString();
        });
      }
    }
  }

  void _controllerChanged() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value == null) return;
    if (value.hasError && _error == null) {
      setState(() => _error = value.errorDescription ?? 'Error del reproductor.');
    } else {
      setState(() {});
    }
  }

  Future<void> _selectAudio(String? id) async {
    final controller = _controller;
    if (controller == null || id == null) return;
    try {
      await controller.selectAudioTrack(id);
      final refreshed = await controller.getAudioTracks();
      if (mounted) setState(() => _audioTracks = refreshed);
    } catch (error) {
      _showTrackError('No se pudo cambiar el audio: ' + error.toString());
    }
  }

  Future<void> _selectVideo(VideoTrack? track) async {
    final controller = _controller;
    if (controller == null || track == null) return;
    try {
      await controller.selectVideoTrack(track);
      final refreshed = await controller.getVideoTracks();
      if (mounted) setState(() => _videoTracks = refreshed);
    } catch (error) {
      _showTrackError('No se pudo cambiar la calidad: ' + error.toString());
    }
  }

  void _showTrackError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: _sources[_activeSourceIndex].url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL de transmisión copiada.')),
    );
  }

  String _audioLabel(VideoAudioTrack track, int index) {
    final label = track.label?.trim();
    if (label != null && label.isNotEmpty) return label;
    final language = track.language?.trim();
    if (language != null && language.isNotEmpty) return language;
    final codec = track.codec?.trim();
    return codec != null && codec.isNotEmpty
        ? codec
        : 'Audio ' + (index + 1).toString();
  }

  String _videoLabel(VideoTrack track, int index) {
    final label = track.label?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (track.height != null) return track.height.toString() + 'p';
    if (track.width != null) return track.width.toString() + ' px';
    return 'Calidad ' + (index + 1).toString();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final durationMs = value?.duration.inMilliseconds ?? 0;
    final positionMs = value?.position.inMilliseconds ?? 0;
    final safePosition = durationMs > 0
        ? positionMs.clamp(0, durationMs).toDouble()
        : 0.0;
    final selectedAudio = _audioTracks.where((track) => track.isSelected);
    final selectedVideo = _videoTracks.where((track) => track.isSelected);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: _studioBg,
              title: Text(
                widget.channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Copiar URL de esta señal',
                  onPressed: _copyUrl,
                  icon: const Icon(Icons.copy, color: _studioCyan),
                ),
                IconButton(
                  tooltip: 'Pantalla completa',
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen, color: _studioGreen),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: value?.isInitialized == true
                      ? value!.aspectRatio
                      : 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: value?.isInitialized == true
                            ? VideoPlayer(controller!)
                            : _loading
                                ? const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      CircularProgressIndicator(color: _studioCyan),
                                      SizedBox(height: 12),
                                      Text(
                                        'Conectando con la señal…',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Text(
                                      _error ?? 'No se pudo cargar el video.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                      ),
                      if (_fullscreen)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: IconButton.filled(
                            tooltip: 'Salir de pantalla completa',
                            onPressed: _toggleFullscreen,
                            icon: const Icon(Icons.fullscreen_exit),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_fullscreen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 14),
                color: _studioBg,
                child: Column(
                  children: <Widget>[
                    if (value?.isInitialized == true)
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              if (value!.isPlaying) {
                                controller!.pause();
                              } else {
                                controller!.play();
                              }
                            },
                            icon: Icon(
                              value!.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: _studioCyan,
                            ),
                          ),
                          Expanded(
                            child: durationMs > 0
                                ? Slider(
                                    min: 0,
                                    max: durationMs.toDouble(),
                                    value: safePosition,
                                    onChanged: (position) => controller!.seekTo(
                                      Duration(milliseconds: position.round()),
                                    ),
                                  )
                                : const Text(
                                    'TRANSMISIÓN EN VIVO',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _studioGreen, fontSize: 10),
                                  ),
                          ),
                          IconButton(
                            tooltip: 'Pantalla completa',
                            onPressed: _toggleFullscreen,
                            icon: const Icon(Icons.fullscreen, color: _studioGreen),
                          ),
                        ],
                      ),
                    if (_sources.length > 1)
                      DropdownButtonFormField<int>(
                        value: _activeSourceIndex,
                        decoration: const InputDecoration(
                          labelText: 'Fuente / respaldo',
                          isDense: true,
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          _sources.length,
                          (index) => DropdownMenuItem<int>(
                            value: index,
                            child: Text(
                              'Fuente ' + (index + 1).toString() + ' · ' +
                                  (Uri.tryParse(_sources[index].source)?.host ??
                                      _sources[index].source),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        onChanged: (index) {
                          if (index != null) _startAt(index);
                        },
                      ),
                    if (_audioTracks.length > 1)
                      DropdownButtonFormField<String>(
                        value: selectedAudio.isNotEmpty
                            ? selectedAudio.first.id
                            : _audioTracks.first.id,
                        decoration: const InputDecoration(
                          labelText: 'Pista de audio',
                          isDense: true,
                        ),
                        items: List<DropdownMenuItem<String>>.generate(
                          _audioTracks.length,
                          (index) => DropdownMenuItem<String>(
                            value: _audioTracks[index].id,
                            child: Text(_audioLabel(_audioTracks[index], index)),
                          ),
                        ),
                        onChanged: _selectAudio,
                      ),
                    if (_videoTracks.length > 1)
                      DropdownButtonFormField<String>(
                        value: selectedVideo.isNotEmpty
                            ? selectedVideo.first.id
                            : _videoTracks.first.id,
                        decoration: const InputDecoration(
                          labelText: 'Calidad de video',
                          isDense: true,
                        ),
                        items: List<DropdownMenuItem<String>>.generate(
                          _videoTracks.length,
                          (index) => DropdownMenuItem<String>(
                            value: _videoTracks[index].id,
                            child: Text(_videoLabel(_videoTracks[index], index)),
                          ),
                        ),
                        onChanged: (id) {
                          if (id == null) return;
                          final matches = _videoTracks.where((track) => track.id == id);
                          if (matches.isNotEmpty) _selectVideo(matches.first);
                        },
                      ),
                    const SizedBox(height: 5),
                    Text(
                      'Fuente ' + (_activeSourceIndex + 1).toString() +
                          ' de ' + _sources.length.toString() +
                          ' · Calidad y audio dependen de las pistas publicadas por la señal.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _studioMuted, fontSize: 10),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: _studioPink, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
