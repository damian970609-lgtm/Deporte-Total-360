import 'package:flutter/foundation.dart';

enum FutbolLibreEventStatus { live, scheduled, finished }

class FutbolLibreChannel {
  const FutbolLibreChannel({required this.name, required this.url});
  final String name;
  final String url;
}

class FutbolLibreEvent {
  const FutbolLibreEvent({
    required this.id,
    required this.sport,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.startsAt,
    required this.status,
    this.detailUrl = '',
    this.channels = const <FutbolLibreChannel>[],
  });

  final String id;
  final String sport;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final DateTime startsAt;
  final FutbolLibreEventStatus status;
  final String detailUrl;
  final List<FutbolLibreChannel> channels;
  String get displayTitle => '$homeTeam vs $awayTeam';

  static DateTime? _date(dynamic value) {
    if (value is num) {
      final raw = value.toInt();
      final ms = raw.abs() < 10000000000 ? raw * 1000 : raw;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    if (value == null) return null;
    return DateTime.tryParse(value.toString().trim())?.toLocal();
  }

  static String _text(dynamic value, [String fallback = '']) {
    final result = (value ?? fallback).toString().trim();
    return result.isEmpty ? fallback : result;
  }

  static List<FutbolLibreEvent> parsePayload(dynamic payload) {
    dynamic rawEvents = payload;
    if (payload is Map) {
      rawEvents = payload['events'] ?? payload['matches'] ?? payload['items'];
    }
    if (rawEvents is! List) return const <FutbolLibreEvent>[];

    final parsed = <FutbolLibreEvent>[];
    for (final raw in rawEvents) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final home = _text(row['homeTeam'] ?? row['home'] ?? row['local']);
      final away = _text(row['awayTeam'] ?? row['away'] ?? row['visitor']);
      final kickoff = _date(row['startsAt'] ?? row['date'] ?? row['kickoff']);
      if (home.isEmpty || away.isEmpty || kickoff == null) continue;

      final channels = <FutbolLibreChannel>[];
      final rawChannels = row['channels'];
      if (rawChannels is List) {
        for (final rawChannel in rawChannels) {
          if (rawChannel is! Map) continue;
          final channel = Map<String, dynamic>.from(rawChannel);
          final name = _text(channel['name'] ?? channel['title']);
          final url = _text(channel['url'] ?? channel['href']);
          final uri = Uri.tryParse(url);
          if (name.isEmpty ||
              uri == null ||
              uri.host.isEmpty ||
              (uri.scheme != 'https' && uri.scheme != 'http')) continue;
          channels.add(FutbolLibreChannel(name: name, url: uri.toString()));
        }
      }

      final statusText = _text(row['status']).toLowerCase();
      final status = statusText.contains('live') ||
              statusText.contains('en vivo') ||
              statusText.contains('directo')
          ? FutbolLibreEventStatus.live
          : statusText.contains('final') ||
                  statusText.contains('finished') ||
                  statusText.contains('finalizado')
              ? FutbolLibreEventStatus.finished
              : FutbolLibreEventStatus.scheduled;

      final detailUrl = _text(row['detailUrl'] ?? row['url']);
      final detailUri = Uri.tryParse(detailUrl);
      final idFallback = home.toLowerCase() + '-' + away.toLowerCase() +
          '-' + kickoff.millisecondsSinceEpoch.toString();
      parsed.add(FutbolLibreEvent(
        id: _text(row['id'], idFallback),
        sport: _text(row['sport'], 'Fútbol'),
        competition: _text(row['competition'], 'Agenda Fútbol Libre'),
        homeTeam: home,
        awayTeam: away,
        startsAt: kickoff,
        status: status,
        detailUrl: detailUri != null &&
                detailUri.host.isNotEmpty &&
                (detailUri.scheme == 'https' || detailUri.scheme == 'http')
            ? detailUri.toString()
            : '',
        channels: channels,
      ));
    }

    final unique = <String, FutbolLibreEvent>{};
    for (final event in parsed) {
      unique[event.id] = event;
    }
    return unique.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }
}

/// La WebView publica aquí la programación que realmente muestra Fútbol Libre.
/// En vivo consume esta misma lista; API-Sports no se utiliza como agenda.
class FutbolLibreAgenda {
  static final ValueNotifier<List<FutbolLibreEvent>> events =
      ValueNotifier<List<FutbolLibreEvent>>(<FutbolLibreEvent>[]);
  static final ValueNotifier<DateTime?> lastUpdated =
      ValueNotifier<DateTime?>(null);

  static void publish(dynamic payload) {
    events.value = FutbolLibreEvent.parsePayload(payload);
    lastUpdated.value = DateTime.now();
  }
}
