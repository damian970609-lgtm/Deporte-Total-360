import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'channel_catalog_service.dart';
import 'live_media_format.dart';

const String _agendaLiveEventsKey = 'dt360_agenda_live_references_v1';
const Duration agendaLivePreparationWindow = Duration(minutes: 5);
const Duration _agendaEventFallbackDuration = Duration(hours: 3);
const Duration _agendaLiveCatalogueMaxAge = Duration(minutes: 15);

/// A schedule row and the channel names published in its event details.
/// The schedule page supplies names only; playback URLs always come from the
/// user's own visible sports-channel catalog.
class AgendaEventReference {
  const AgendaEventReference({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.channelReferences,
    this.competition = '',
    this.status = 'unknown',
    this.endsAt,
    this.detailUrl = '',
    this.updatedAt,
  });

  final String id;
  final String title;
  final String competition;
  final DateTime startsAt;
  final DateTime? endsAt;
  final List<String> channelReferences;
  final String status;
  final String detailUrl;
  final DateTime? updatedAt;

  DateTime get effectiveEndsAt =>
      endsAt ?? startsAt.add(_agendaEventFallbackDuration);

  bool get isFinished {
    final normalized = status
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return const <String>{
      'finished',
      'final',
      'finalizado',
      'finalizada',
      'terminado',
      'terminada',
      'completed',
      'ended',
      'cancelled',
      'canceled',
      'postponed',
      'suspendido',
      'suspendida',
      'cancelado',
      'cancelada',
    }.contains(normalized);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'competition': competition,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'channelReferences': channelReferences,
        'status': status,
        'detailUrl': detailUrl,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static AgendaEventReference? tryParse(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final title = (map['title'] ?? map['eventTitle'] ?? map['match'] ?? '')
        .toString()
        .trim();
    final rawStart = (map['startsAt'] ?? map['startAt'] ?? map['dateTime'] ?? '')
        .toString()
        .trim();
    final startsAt = DateTime.tryParse(rawStart);
    if (title.isEmpty || startsAt == null) return null;

    final refs = <String>[];
    final rawRefs = map['channelReferences'] ?? map['channels'] ?? map['sources'];
    if (rawRefs is List) {
      for (final raw in rawRefs) {
        final label = raw is Map
            ? (raw['name'] ?? raw['title'] ?? raw['channel'] ?? '').toString()
            : raw.toString();
        final clean = normalizeAgendaChannelReference(label);
        if (clean.isNotEmpty && !refs.contains(clean)) refs.add(clean);
      }
    }

    final explicitId = (map['id'] ?? map['eventId'] ?? '').toString().trim();
    final id = explicitId.isNotEmpty
        ? explicitId
        : _eventKey(title, startsAt);
    final endValue = (map['endsAt'] ?? map['endAt'] ?? '').toString().trim();
    final endsAt = endValue.isEmpty ? null : DateTime.tryParse(endValue);
    final status = (map['status'] ?? 'unknown').toString().trim();
    final detailUrl = (map['detailUrl'] ?? map['url'] ?? '').toString().trim();
    final updatedValue = (map['updatedAt'] ?? '').toString().trim();

    return AgendaEventReference(
      id: id,
      title: title,
      competition: (map['competition'] ?? map['league'] ?? '').toString().trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      channelReferences: refs,
      status: status.isEmpty ? 'unknown' : status,
      detailUrl: detailUrl,
      updatedAt: DateTime.tryParse(updatedValue),
    );
  }

  AgendaEventReference merge(AgendaEventReference previous) {
    final references = channelReferences.isNotEmpty
        ? channelReferences
        : previous.channelReferences;
    final hasStatus = status.toLowerCase() != 'unknown' &&
        status.toLowerCase() != 'scheduled';
    return AgendaEventReference(
      id: id,
      title: title.isNotEmpty ? title : previous.title,
      competition: competition.isNotEmpty ? competition : previous.competition,
      startsAt: startsAt,
      endsAt: endsAt ?? previous.endsAt,
      channelReferences: references,
      status: hasStatus ? status : previous.status,
      detailUrl: detailUrl.isNotEmpty ? detailUrl : previous.detailUrl,
      updatedAt: updatedAt ?? previous.updatedAt,
    );
  }
}

String _eventKey(String title, DateTime startsAt) {
  final normalized = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final date = startsAt.toLocal();
  return '${normalized}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}';
}

/// Removes labels and quality/language suffixes while preserving channel
/// numbers (ESPN 2 must never be treated as ESPN 1).
String normalizeAgendaChannelReference(String value) {
  var text = value.trim().toLowerCase();
  text = text.replaceAll(RegExp(r'^(?:fuente|canal|señal|senal|opción|opcion)\s*\d*\s*[:.\-]?\s*'), '');
  text = text.replaceAll(RegExp(r'\s*[·|•]\s*(?:español|espanol|english|inglés|ingles|português|portugues|brasil|latino).*$', caseSensitive: false), '');
  text = text
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('+', ' plus ');
  text = text.replaceAll(
    RegExp(r'\b(?:hd|sd|fhd|uhd|4k|8k|1080p|720p|576p|480p|50fps|60fps)\b'),
    ' ',
  );
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class AgendaLiveAssignment {
  const AgendaLiveAssignment({
    required this.event,
    required this.channel,
  });

  final AgendaEventReference event;
  final SportsChannel channel;
}

class AgendaLivePendingEvent {
  const AgendaLivePendingEvent({
    required this.event,
    required this.status,
    required this.detail,
  });

  final AgendaEventReference event;
  final String status;
  final String detail;
}

class AgendaLiveBoardState {
  const AgendaLiveBoardState({
    required this.assignments,
    required this.pending,
    required this.catalogueChannelCount,
  });

  final List<AgendaLiveAssignment> assignments;
  final List<AgendaLivePendingEvent> pending;
  final int catalogueChannelCount;
}

/// Coordinates the five-minute preparation window and temporary allocation of
/// one matching, visible sports channel to one of the eight live players.
class AgendaLiveService {
  AgendaLiveService({ChannelCatalogService? catalogService})
      : _catalogService = catalogService ?? channelCatalogService;

  final ChannelCatalogService _catalogService;

  Future<void> captureAgendaEvents(dynamic rawPayload) async {
    final rows = rawPayload is List
        ? rawPayload
        : rawPayload is Map && rawPayload['events'] is List
            ? rawPayload['events'] as List
            : const <dynamic>[];
    if (rows.isEmpty) return;

    final incoming = rows
        .map(AgendaEventReference.tryParse)
        .whereType<AgendaEventReference>()
        .toList(growable: false);
    if (incoming.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = await _readEvents(prefs);
    final byId = <String, AgendaEventReference>{
      for (final event in existing) event.id: event,
    };
    for (final event in incoming) {
      final previous = byId[event.id];
      byId[event.id] = previous == null ? event : event.merge(previous);
    }

    final now = DateTime.now();
    final retained = byId.values
        .where((event) =>
            !event.isFinished &&
            now.isBefore(event.effectiveEndsAt.add(const Duration(hours: 1))) &&
            !event.startsAt.isBefore(now.subtract(const Duration(hours: 24))))
        .toList(growable: false)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    await prefs.setString(
      _agendaLiveEventsKey,
      jsonEncode(retained.map((event) => event.toJson()).toList()),
    );
  }

  Future<List<AgendaEventReference>> loadCapturedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEvents(prefs);
  }

  Future<AgendaLiveBoardState> buildBoardState({
    DateTime? now,
    List<SportsChannel>? channels,
  }) async {
    final current = (now ?? DateTime.now()).toLocal();
    final prefs = await SharedPreferences.getInstance();
    final stored = await _readEvents(prefs);
    final activeEvents = stored
        .where((event) =>
            !event.isFinished &&
            current.isBefore(event.effectiveEndsAt) &&
            !event.startsAt.isBefore(current.subtract(const Duration(hours: 24))))
        .toList(growable: false)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (activeEvents.length != stored.length) {
      await prefs.setString(
        _agendaLiveEventsKey,
        jsonEncode(activeEvents.map((event) => event.toJson()).toList()),
      );
    }

    final dueEvents = activeEvents
        .where((event) => !current.isBefore(
              event.startsAt.subtract(agendaLivePreparationWindow),
            ))
        .toList(growable: false);
    final availableChannels = dueEvents.any((event) => event.channelReferences.isNotEmpty)
        ? (channels ?? await _loadVisibleSportsChannels())
        : (channels ?? <SportsChannel>[]);
    final assignments = <AgendaLiveAssignment>[];
    final pending = <AgendaLivePendingEvent>[];
    final usedUrls = <String>{};

    for (final event in activeEvents) {
      if (assignments.length >= 8) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'ESPERANDO UN REPRODUCTOR',
          detail: 'Los ocho reproductores están ocupados. Este evento se asignará cuando se libere uno.',
        ));
        continue;
      }

      if (current.isBefore(event.startsAt.subtract(agendaLivePreparationWindow))) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'ESPERANDO LA VENTANA DE PREPARACIÓN',
          detail: 'La búsqueda automática comienza cinco minutos antes del evento.',
        ));
        continue;
      }

      if (event.channelReferences.isEmpty) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'FALTAN LOS CANALES DE REFERENCIA',
          detail: 'Abre el evento en Agenda deportiva para que la app lea los canales publicados en su ficha.',
        ));
        continue;
      }

      SportsChannel? matched;
      for (final reference in event.channelReferences) {
        final candidate = _findMatchingChannel(reference, availableChannels)
            .where((channel) => !usedUrls.contains(channel.url))
            .firstOrNull;
        if (candidate != null) {
          matched = candidate;
          break;
        }
      }

      if (matched == null) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'BUSCANDO EN CANALES DEPORTIVOS',
          detail: 'Referencias: ${event.channelReferences.join(', ')}. Aún no hay una coincidencia visible y reproducible en tu catálogo.',
        ));
        continue;
      }

      usedUrls.add(matched.url);
      assignments.add(AgendaLiveAssignment(event: event, channel: matched));
    }

    return AgendaLiveBoardState(
      assignments: assignments,
      pending: pending.take(8 - assignments.length).toList(growable: false),
      catalogueChannelCount: availableChannels.length,
    );
  }

  Future<List<SportsChannel>> _loadVisibleSportsChannels() async {
    final cached = await loadCachedVisibleSportsChannels();
    if (cached.isNotEmpty &&
        await isCachedPublicChannelSnapshotFresh(
          maxAge: _agendaLiveCatalogueMaxAge,
        )) {
      return cached
          .where((channel) =>
              channel.isSports &&
              channel.visible &&
              isSupportedChannelPlaybackUrl(channel.url))
          .toList(growable: false);
    }

    try {
      final all = <SportsChannel>[];
      var offset = 0;
      for (var pageNumber = 0; pageNumber < 100; pageNumber++) {
        final page = await _catalogService.fetchPublicChannelPage(
          offset: offset,
          limit: 2000,
        );
        all.addAll(page.channels);
        if (!page.hasMore || page.channels.isEmpty) break;
        final nextOffset = page.offset + page.channels.length;
        if (nextOffset <= offset) {
          throw StateError('El catálogo de Canales deportivos no avanzó a la siguiente página.');
        }
        offset = nextOffset;
        if (pageNumber == 99) {
          throw StateError('El catálogo de Canales deportivos supera el límite de páginas.');
        }
      }
      await saveCachedPublicChannelSnapshot(all);
      return all
          .where((channel) =>
              channel.isSports &&
              channel.visible &&
              isSupportedChannelPlaybackUrl(channel.url))
          .toList(growable: false);
    } catch (_) {
      if (cached.isNotEmpty) {
        return cached
            .where((channel) =>
                channel.isSports &&
                channel.visible &&
                isSupportedChannelPlaybackUrl(channel.url))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  static List<SportsChannel> _findMatchingChannel(
    String reference,
    List<SportsChannel> channels,
  ) {
    final normalizedReference = normalizeAgendaChannelReference(reference);
    if (normalizedReference.isEmpty) return <SportsChannel>[];
    final matches = channels.where((channel) {
      if (!channel.isSports ||
          !channel.visible ||
          !isSupportedChannelPlaybackUrl(channel.url)) {
        return false;
      }
      return <String>[
        channel.name,
        channel.identifier,
        channel.tvgId,
      ].any((label) =>
          normalizeAgendaChannelReference(label) == normalizedReference);
    }).toList(growable: false);

    final sorted = List<SportsChannel>.of(matches)
      ..sort((first, second) {
        final firstLanguage = first.language == 'es' ? 0 : first.language == 'en' ? 1 : 2;
        final secondLanguage = second.language == 'es' ? 0 : second.language == 'en' ? 1 : 2;
        return firstLanguage.compareTo(secondLanguage);
      });
    return sorted;
  }

  static Future<List<AgendaEventReference>> _readEvents(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_agendaLiveEventsKey);
    if (raw == null || raw.isEmpty) return <AgendaEventReference>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AgendaEventReference>[];
      return decoded
          .map(AgendaEventReference.tryParse)
          .whereType<AgendaEventReference>()
          .toList(growable: false);
    } catch (_) {
      return <AgendaEventReference>[];
    }
  }
}

extension _FirstOrNullAgenda<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
