import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int maxChannelProxiesPerChannel = 10;
const String _channelProxyStorageKey = 'dt360_channel_proxy_failover_v1';

/// Proxy manual por canal. Admite HTTP y SOCKS4/SOCKS5.
class ChannelProxyEndpoint {
  const ChannelProxyEndpoint({
    required this.scheme,
    required this.host,
    required this.port,
    this.username = '',
    this.password = '',
  });

  final String scheme;
  final String host;
  final int port;
  final String username;
  final String password;

  String get id => '${scheme.toLowerCase()}://${host.toLowerCase()}:$port/$username';

  String get displayAddress {
    final safeHost = host.contains(':') ? '[$host]' : host;
    return '${scheme.toUpperCase()} · $safeHost:$port';
  }

  Map<String, Object> toJson() => <String, Object>{
        'scheme': scheme,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
      };

  factory ChannelProxyEndpoint.fromJson(Map<String, dynamic> json) {
    final scheme = (json['scheme'] ?? 'http').toString().toLowerCase();
    final host = (json['host'] ?? '').toString().trim();
    final port = int.tryParse((json['port'] ?? '').toString()) ?? 0;
    if (!_supportedProxySchemes.contains(scheme) ||
        host.isEmpty ||
        port < 1 ||
        port > 65535) {
      throw const FormatException('El proxy guardado no es válido.');
    }
    return ChannelProxyEndpoint(
      scheme: scheme,
      host: host,
      port: port,
      username: (json['username'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
    );
  }

  static const Set<String> _supportedProxySchemes = <String>{
    'http',
    'socks',
    'socks4',
    'socks5',
  };

  static ChannelProxyEndpoint parse(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('Escribe la dirección del proxy.');
    }
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !_supportedProxySchemes.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.port < 1 ||
        uri.port > 65535 ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException(
        'Formato no válido. Usa host:puerto, http://host:puerto o socks5://host:puerto.',
      );
    }
    final userInfo = uri.userInfo;
    final separator = userInfo.indexOf(':');
    final username = userInfo.isEmpty
        ? ''
        : Uri.decodeComponent(
            separator < 0 ? userInfo : userInfo.substring(0, separator),
          );
    final password = separator < 0
        ? ''
        : Uri.decodeComponent(userInfo.substring(separator + 1));
    return ChannelProxyEndpoint(
      scheme: uri.scheme.toLowerCase() == 'socks'
          ? 'socks5'
          : uri.scheme.toLowerCase(),
      host: uri.host,
      port: uri.port,
      username: username,
      password: password,
    );
  }

  Map<String, Object> toPlatformArguments() => <String, Object>{
        'type': scheme == 'socks' ? 'socks5' : scheme,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
      };
}

/// Almacena hasta diez proxies por canal, solo en el teléfono del usuario.
class ChannelProxyStore {
  Future<Map<String, List<ChannelProxyEndpoint>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_channelProxyStorageKey);
    if (raw == null || raw.isEmpty) return <String, List<ChannelProxyEndpoint>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<ChannelProxyEndpoint>>{};
      final result = <String, List<ChannelProxyEndpoint>>{};
      for (final entry in decoded.entries) {
        if (entry.value is! List) continue;
        final proxies = <ChannelProxyEndpoint>[];
        for (final row in (entry.value as List).whereType<Map>()) {
          try {
            proxies.add(ChannelProxyEndpoint.fromJson(
              Map<String, dynamic>.from(row),
            ));
          } on FormatException {
            // Una entrada dañada no debe borrar las demás configuraciones.
          }
        }
        if (proxies.isNotEmpty) {
          result[entry.key.toString()] =
              proxies.take(maxChannelProxiesPerChannel).toList(growable: false);
        }
      }
      return result;
    } catch (_) {
      return <String, List<ChannelProxyEndpoint>>{};
    }
  }

  Future<List<ChannelProxyEndpoint>> loadForChannel(String channelId) async {
    final all = await loadAll();
    return all[channelId] ?? <ChannelProxyEndpoint>[];
  }

  Future<void> saveForChannel(
    String channelId,
    List<ChannelProxyEndpoint> proxies,
  ) async {
    final safeId = channelId.trim();
    if (safeId.isEmpty) throw ArgumentError.value(channelId, 'channelId');
    if (proxies.length > maxChannelProxiesPerChannel) {
      throw const FormatException('Cada canal admite un máximo de 10 proxies.');
    }
    final all = await loadAll();
    final unique = <String, ChannelProxyEndpoint>{};
    for (final proxy in proxies) {
      unique[proxy.id] = proxy;
    }
    all[safeId] = unique.values.take(maxChannelProxiesPerChannel).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _channelProxyStorageKey,
      jsonEncode(all.map((key, value) => MapEntry(
            key,
            value.map((proxy) => proxy.toJson()).toList(growable: false),
          )),
      ),
    );
  }

  Future<void> moveToFront(String channelId, String proxyId) async {
    final proxies = await loadForChannel(channelId);
    final index = proxies.indexWhere((proxy) => proxy.id == proxyId);
    if (index <= 0) return;
    final reordered = List<ChannelProxyEndpoint>.from(proxies);
    final selected = reordered.removeAt(index);
    reordered.insert(0, selected);
    await saveForChannel(channelId, reordered);
  }
}

/// Controla el proxy del reproductor Android nativo. El canal vuelve a la
/// conexión directa al cerrar el reproductor o al abandonar la reproducción.
class ChannelProxyPlatform {
  static const MethodChannel _channel = MethodChannel('dt360/channel_proxy');

  static Future<void> apply(ChannelProxyEndpoint proxy) async {
    await _channel.invokeMethod<void>('setProxy', proxy.toPlatformArguments());
  }

  static Future<void> clear() async {
    await _channel.invokeMethod<void>('clearProxy');
  }
}
