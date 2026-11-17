import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'agenda_live_service.dart';

const Color _agendaChannelsBg = Color(0xFF000000);
const Color _agendaChannelsPanel = Color(0xFF07090D);
const Color _agendaChannelsBlue = Color(0xFF00A3FF);
const Color _agendaChannelsMuted = Color(0xFFEAF0F8);

class AgendaChannelsScreen extends StatefulWidget {
  const AgendaChannelsScreen({
    super.key,
    required this.onOpenAgenda,
  });

  final VoidCallback onOpenAgenda;

  @override
  State<AgendaChannelsScreen> createState() => _AgendaChannelsScreenState();
}

class _AgendaChannelOccurrence {
  const _AgendaChannelOccurrence({
    required this.event,
    required this.option,
  });

  final AgendaEventReference event;
  final AgendaTransmissionOption option;
}

class _AgendaChannelEntry {
  _AgendaChannelEntry(this.name);

  final String name;
  final List<_AgendaChannelOccurrence> occurrences =
      <_AgendaChannelOccurrence>[];
}

String _normalizeChannelName(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _AgendaChannelsScreenState extends State<AgendaChannelsScreen> {
  final AgendaLiveService _service = AgendaLiveService();
  Timer? _refreshTimer;
  List<AgendaEventReference> _events = <AgendaEventReference>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final events = await _service.loadCapturedEvents();
      if (!mounted) return;
      events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_AgendaChannelEntry> _buildChannelEntries() {
    final byName = <String, _AgendaChannelEntry>{};
    for (final event in _events) {
      for (final option in event.transmissionOptions) {
        final key = _normalizeChannelName(option.name);
        if (key.isEmpty || !isSafeAgendaTransmissionUrl(option.url)) continue;
        final entry = byName.putIfAbsent(
          key,
          () => _AgendaChannelEntry(option.name.trim()),
        );
        final alreadyAdded = entry.occurrences.any(
          (item) =>
              item.event.id == event.id && item.option.url == option.url,
        );
        if (!alreadyAdded) {
          entry.occurrences.add(
            _AgendaChannelOccurrence(event: event, option: option),
          );
        }
      }
    }

    final entries = byName.values.toList(growable: false);
    for (final entry in entries) {
      entry.occurrences.sort((first, second) {
        final popularity = second.option.popularityScore.compareTo(
          first.option.popularityScore,
        );
        if (popularity != 0) return popularity;
        final time = first.event.startsAt.compareTo(second.event.startsAt);
        if (time != 0) return time;
        return first.option.order.compareTo(second.option.order);
      });
    }
    entries.sort((first, second) {
      final availability = second.occurrences.length.compareTo(
        first.occurrences.length,
      );
      if (availability != 0) return availability;
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return entries;
  }

  String _eventTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} · '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final channels = _buildChannelEntries();
    final totalOccurrences = channels.fold<int>(
      0,
      (total, channel) => total + channel.occurrences.length,
    );

    return Scaffold(
      backgroundColor: _agendaChannelsBg,
      appBar: AppBar(
        backgroundColor: _agendaChannelsBg,
        title: const Text(
          'CANALES DEPORTIVOS',
          style: TextStyle(
            color: _agendaChannelsBlue,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _refresh,
            tooltip: 'Actualizar canales de la agenda',
            icon: const Icon(Icons.refresh_rounded, color: _agendaChannelsBlue),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: _agendaChannelsPanel,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'CANALES PUBLICADOS EN FÚTBOL LIBRE',
                  style: TextStyle(
                    color: _agendaChannelsBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${channels.length} canales únicos · ${totalOccurrences} opciones asociadas a partidos',
                  style: const TextStyle(
                    color: _agendaChannelsMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Cada opción abre la página original y conserva el reproductor que publica la fuente.',
                  style: TextStyle(
                    color: _agendaChannelsMuted,
                    fontSize: 9,
                    height: 1.35,
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: _agendaChannelsBlue,
                      backgroundColor: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: channels.isEmpty
                ? _EmptyAgendaChannels(onOpenAgenda: widget.onOpenAgenda)
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: _agendaChannelsBlue,
                    backgroundColor: _agendaChannelsPanel,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _agendaChannelsPanel,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: _agendaChannelsBlue.withAlpha(110),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.live_tv_rounded,
                                      color: _agendaChannelsBlue,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        channel.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${channel.occurrences.length} partidos',
                                      style: const TextStyle(
                                        color: _agendaChannelsMuted,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Color(0xFF193044),
                                  height: 16,
                                ),
                                for (var occurrenceIndex = 0;
                                    occurrenceIndex < channel.occurrences.length;
                                    occurrenceIndex++)
                                  _AgendaChannelOccurrenceTile(
                                    occurrence: channel.occurrences[
                                        occurrenceIndex],
                                    eventTime: _eventTime(
                                      channel.occurrences[occurrenceIndex]
                                          .event.startsAt,
                                    ),
                                    isPreferred: occurrenceIndex == 0,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgendaChannelOccurrenceTile extends StatelessWidget {
  const _AgendaChannelOccurrenceTile({
    required this.occurrence,
    required this.eventTime,
    required this.isPreferred,
  });

  final _AgendaChannelOccurrence occurrence;
  final String eventTime;
  final bool isPreferred;

  @override
  Widget build(BuildContext context) {
    final option = occurrence.option;
    final event = occurrence.event;
    final hasPopularityMetric = option.popularityScore > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1118),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isPreferred
              ? _agendaChannelsBlue.withAlpha(180)
              : Colors.white.withAlpha(30),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
        leading: Icon(
          Icons.play_circle_fill_rounded,
          color: isPreferred ? _agendaChannelsBlue : _agendaChannelsMuted,
          size: 23,
        ),
        title: Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
        subtitle: Text(
          isPreferred
              ? (hasPopularityMetric
                  ? 'MÁS POPULAR · $eventTime'
                  : 'PRIMERA OPCIÓN PUBLICADA · $eventTime')
              : '$eventTime · OPCIÓN DE LA AGENDA',
          maxLines: 2,
          style: TextStyle(
            color: isPreferred ? _agendaChannelsBlue : _agendaChannelsMuted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: const Icon(
          Icons.open_in_new_rounded,
          color: _agendaChannelsBlue,
          size: 17,
        ),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AgendaTransmissionWebView(
                title: '${option.name} · ${event.title}',
                url: option.url,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyAgendaChannels extends StatelessWidget {
  const _EmptyAgendaChannels({required this.onOpenAgenda});

  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.live_tv_rounded,
              color: _agendaChannelsBlue,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'TODAVÍA NO HAY CANALES CAPTURADOS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Abre un partido en Agenda y despliega sus canales. La app guardará los nombres y las páginas de reproducción que estén publicadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _agendaChannelsMuted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onOpenAgenda,
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('ABRIR AGENDA'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre la página original publicada por la Agenda y conserva su reproductor.
/// No extrae URLs internas de vídeo ni interfiere con controles o protecciones.
class AgendaTransmissionWebView extends StatefulWidget {
  const AgendaTransmissionWebView({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<AgendaTransmissionWebView> createState() =>
      _AgendaTransmissionWebViewState();
}

class _AgendaTransmissionWebViewState extends State<AgendaTransmissionWebView> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final safe = isSafeAgendaTransmissionUrl(widget.url);
    return Scaffold(
      backgroundColor: _agendaChannelsBg,
      appBar: AppBar(
        backgroundColor: _agendaChannelsBg,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: !safe
          ? const Center(
              child: Text(
                'El enlace no es una página HTTPS segura.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: <Widget>[
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    javaScriptCanOpenWindowsAutomatically: false,
                    supportMultipleWindows: false,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    supportZoom: false,
                  ),
                  shouldOverrideUrlLoading: (controller, action) async {
                    final target = action.request.url;
                    if (target == null) return NavigationActionPolicy.CANCEL;
                    if (target.scheme == 'about') {
                      return NavigationActionPolicy.ALLOW;
                    }
                    return target.scheme == 'https' &&
                            target.userInfo.isEmpty
                        ? NavigationActionPolicy.ALLOW
                        : NavigationActionPolicy.CANCEL;
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame == false || !mounted) return;
                    setState(() => _error =
                        'No se pudo abrir esta opción. Comprueba la conexión.');
                  },
                ),
                if (_error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xDD000000),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _agendaChannelsMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
