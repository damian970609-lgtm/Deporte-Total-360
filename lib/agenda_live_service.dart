import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _agendaLiveEventsKey = 'dt360_agenda_live_references_v1';
const String _agendaChannelsKey = 'dt360_agenda_channels_v1';
const Duration agendaLivePreparationWindow = Duration(minutes: 5);
const Duration _agendaEventFallbackDuration = Duration(hours: 3);

/// A source option explicitly exposed as a clickable HTTPS link by the agenda.
/// The app stores the page link; it does not inspect hidden iframe/video URLs.
class AgendaTransmissionOption {
  const AgendaTransmissionOption({
    required this.id,
    required this.name,
    required this.url,
    required this.order,
    this.popularityScore = 0,
  });

  final String id;
  final String name;
  final String url;
  final int order;
  final int popularityScore;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'url': url,
        'order': order,
        'popularityScore': popularityScore,
      };

  static AgendaTransmissionOption? tryParse(dynamic value, int fallbackOrder) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final url = (map['url'] ?? map['href'] ?? '').toString().trim();
    if (!isSafeAgendaTransmissionUrl(url)) return null;
    final name = (map['name'] ?? map['label'] ?? map['title'] ?? '')
        .toString()
        .trim();
    final order = int.tryParse((map['order'] ?? fallbackOrder).toString()) ??
        fallbackOrder;
    final score = int.tryParse(
          (map['popularityScore'] ?? map['popularity'] ?? map['views'] ?? 0)
              .toString(),
        ) ??
        0;
    final explicitId = (map['id'] ?? '').toString().trim();
    return AgendaTransmissionOption(
      id: explicitId.isNotEmpty ? explicitId : _optionKey(url, order),
      name: name.isNotEmpty ? name : 'Opción ${fallbackOrder + 1}',
      url: url,
      order: order,
      popularityScore: score < 0 ? 0 : score,
    );
  }
}

String _optionKey(String url, int order) =>
    '${order}_${url.hashCode.toRadixString(16)}';

/// Only visible HTTPS links are accepted. Credentials and non-web schemes
/// are deliberately excluded.
bool isSafeAgendaTransmissionUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

/// Highest published popularity score wins. When the site exposes no metric,
/// its own order is preserved instead of inventing popularity data.
List<AgendaTransmissionOption> rankAgendaTransmissionOptions(
  Iterable<AgendaTransmissionOption> options,
) {
  final ranked = List<AgendaTransmissionOption>.of(options)
    ..sort((first, second) {
      final popularity =
          second.popularityScore.compareTo(first.popularityScore);
      if (popularity != 0) return popularity;
      return first.order.compareTo(second.order);
    });
  return ranked;
}

class AgendaEventReference {
  const AgendaEventReference({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.channelReferences,
    this.transmissionOptions = const <AgendaTransmissionOption>[],
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
  final List<AgendaTransmissionOption> transmissionOptions;
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
      'finished', 'final', 'finalizado', 'finalizada', 'terminado',
      'terminada', 'completed', 'ended', 'cancelled', 'canceled',
      'postponed', 'suspendido', 'suspendida', 'cancelado', 'cancelada',
    }.contains(normalized);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'competition': competition,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'channelReferences': channelReferences,
        'transmissionOptions':
            transmissionOptions.map((option) => option.toJson()).toList(),
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
    final rawStart =
        (map['startsAt'] ?? map['startAt'] ?? map['dateTime'] ?? '')
            .toString()
            .trim();
    final startsAt = DateTime.tryParse(rawStart);
    if (title.isEmpty || startsAt == null) return null;

    final refs = <String>[];
    final rawRefs =
        map['channelReferences'] ?? map['channels'] ?? map['sources'];
    if (rawRefs is List) {
      for (final raw in rawRefs) {
        final label = raw is Map
            ? (raw['name'] ?? raw['title'] ?? raw['channel'] ?? '').toString()
            : raw.toString();
        final clean = normalizeAgendaChannelReference(label);
        if (clean.isNotEmpty && !refs.contains(clean)) refs.add(clean);
      }
    }

    final rawOptions =
        map['transmissionOptions'] ?? map['options'] ?? map['broadcasts'];
    final options = <AgendaTransmissionOption>[];
    if (rawOptions is List) {
      for (var index = 0; index < rawOptions.length; index++) {
        final option =
            AgendaTransmissionOption.tryParse(rawOptions[index], index);
        if (option != null && !options.any((item) => item.url == option.url)) {
          options.add(option);
        }
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
      transmissionOptions: options,
      status: status.isEmpty ? 'unknown' : status,
      detailUrl: detailUrl,
      updatedAt: DateTime.tryParse(updatedValue),
    );
  }

  AgendaEventReference merge(AgendaEventReference previous) {
    final references = channelReferences.isNotEmpty
        ? channelReferences
        : previous.channelReferences;
    final options = transmissionOptions.isNotEmpty
        ? transmissionOptions
        : previous.transmissionOptions;
    final hasStatus = status.toLowerCase() != 'unknown' &&
        status.toLowerCase() != 'scheduled';
    return AgendaEventReference(
      id: id,
      title: title.isNotEmpty ? title : previous.title,
      competition: competition.isNotEmpty ? competition : previous.competition,
      startsAt: startsAt,
      endsAt: endsAt ?? previous.endsAt,
      channelReferences: references,
      transmissionOptions: options,
      status: hasStatus ? status : previous.status,
      detailUrl: detailUrl.isNotEmpty ? detailUrl : previous.detailUrl,
      updatedAt: updatedAt ?? previous.updatedAt,
    );
  }
}

/// Indica cuándo un evento debe aparecer en «En vivo»: desde cinco minutos
/// antes del inicio y hasta su finalización, sin mostrar eventos lejanos.
bool isAgendaEventWithinLiveWindow(
  AgendaEventReference event,
  DateTime now,
) =>
    !event.isFinished &&
    !now.isBefore(event.startsAt.subtract(agendaLivePreparationWindow)) &&
    now.isBefore(event.effectiveEndsAt);

String _eventKey(String title, DateTime startsAt) {
  final normalized = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final date = startsAt.toLocal();
  return '${normalized}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}';
}

String normalizeAgendaChannelReference(String value) {
  var text = value.trim().toLowerCase();
  text = text.replaceAll(
    RegExp(r'^(?:fuente|canal|señal|senal|opción|opcion)\s*\d*\s*[:.\-]?\s*'),
    '',
  );
  text = text.replaceAll(
    RegExp(
      r'\s*[·|•]\s*(?:español|espanol|english|inglés|ingles|português|portugues|brasil|latino).*$',
      caseSensitive: false,
    ),
    '',
  );
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
  text = text.replaceAllMapped(
    RegExp(r'([a-z])([0-9])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  text = text.replaceAll(
    RegExp(r'\b(?:us|uk|gb|ca|mx|ar|co|ve|cl|pe|uy|py|bo|cr|gt|hn|ni|pa|cw|jm|do|sv)\b'),
    ' ',
  );
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class AgendaLiveAssignment {
  const AgendaLiveAssignment({
    required this.event,
    required this.option,
  });

  final AgendaEventReference event;
  final AgendaTransmissionOption option;
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
    required this.transmissionOptionCount,
  });

  final List<AgendaLiveAssignment> assignments;
  final List<AgendaLivePendingEvent> pending;
  final int transmissionOptionCount;
}

class AgendaLiveService {
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

  /// Guarda los canales independientes publicados debajo de la agenda.
  /// Solo almacena enlaces HTTPS visibles/publicados por la propia página.
  Future<void> captureAgendaChannels(dynamic rawPayload) async {
    final rows = rawPayload is List
        ? rawPayload
        : rawPayload is Map && rawPayload['channels'] is List
            ? rawPayload['channels'] as List
            : const <dynamic>[];
    if (rows.isEmpty) return;

    final incoming = <AgendaTransmissionOption>[];
    for (var index = 0; index < rows.length; index++) {
      final option = AgendaTransmissionOption.tryParse(rows[index], index);
      if (option != null && !incoming.any((item) => item.url == option.url)) {
        incoming.add(option);
      }
    }
    if (incoming.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = _readChannels(prefs);
    final byUrl = <String, AgendaTransmissionOption>{
      for (final option in previous) option.url: option,
    };
    for (final option in incoming) {
      byUrl[option.url] = option;
    }
    final retained = byUrl.values.toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
    await prefs.setString(
      _agendaChannelsKey,
      jsonEncode(retained.map((option) => option.toJson()).toList()),
    );
  }

  /// Devuelve el catálogo de canales independientes guardado desde Agenda.
  Future<List<AgendaTransmissionOption>> loadCapturedChannels() async {
    final prefs = await SharedPreferences.getInstance();
    return _readChannels(prefs);
  }

  static List<AgendaTransmissionOption> _readChannels(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_agendaChannelsKey);
    if (raw == null || raw.isEmpty) return <AgendaTransmissionOption>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AgendaTransmissionOption>[];
      return decoded
          .asMap()
          .entries
          .map((entry) => AgendaTransmissionOption.tryParse(
                entry.value,
                entry.key,
              ))
          .whereType<AgendaTransmissionOption>()
          .toList(growable: false);
    } catch (_) {
      return <AgendaTransmissionOption>[];
    }
  }

  Future<AgendaLiveBoardState> buildBoardState({DateTime? now}) async {
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

      if (current.isBefore(
        event.startsAt.subtract(agendaLivePreparationWindow),
      )) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'ESPERANDO LA VENTANA DE PREPARACIÓN',
          detail: 'La búsqueda automática comienza cinco minutos antes del evento.',
        ));
        continue;
      }

      if (event.transmissionOptions.isEmpty) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'FALTAN OPCIONES DE TRANSMISIÓN',
          detail: 'Abre el evento en Agenda y toca una opción visible de transmisión. La app no consulta listas IPTV.',
        ));
        continue;
      }

      final ranked = rankAgendaTransmissionOptions(event.transmissionOptions);
      final selected = ranked.where((option) =>
          isSafeAgendaTransmissionUrl(option.url) &&
          !usedUrls.contains(option.url));
      final option = selected.isEmpty ? null : selected.first;
      if (option == null) {
        pending.add(AgendaLivePendingEvent(
          event: event,
          status: 'BUSCANDO UNA OPCIÓN DISPONIBLE',
          detail: 'Las opciones publicadas ya están asignadas a otro evento o no son enlaces HTTPS seguros.',
        ));
        continue;
      }

      usedUrls.add(option.url);
      assignments.add(AgendaLiveAssignment(event: event, option: option));
    }

    final optionCount = activeEvents.fold<int>(
      0,
      (total, event) => total + event.transmissionOptions.length,
    );
    return AgendaLiveBoardState(
      assignments: assignments,
      pending: pending.take(8 - assignments.length).toList(growable: false),
      transmissionOptionCount: optionCount,
    );
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
