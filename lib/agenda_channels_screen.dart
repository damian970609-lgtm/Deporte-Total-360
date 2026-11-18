import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'agenda_live_service.dart';
import 'live_channels_screen.dart';

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

class _AgendaChannelsScreenState extends State<AgendaChannelsScreen> {
  final AgendaLiveService _service = AgendaLiveService();
  Timer? _refreshTimer;
  List<AgendaEventReference> _events = <AgendaEventReference>[];
  List<AgendaTransmissionOption> _channels = <AgendaTransmissionOption>[];
  LivePlayerSource? _selectedSource;
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
      final results = await Future.wait<Object>(<Future<Object>>[
        _service.loadCapturedEvents(),
        _service.loadCapturedChannels(),
      ]);
      if (!mounted) return;
      final events = results[0] as List<AgendaEventReference>;
      final channels = results[1] as List<AgendaTransmissionOption>;
      events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      channels.sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _events = events;
        _channels = channels;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    final eventsWithOptions = _events
        .where((event) => event.transmissionOptions.isNotEmpty)
        .toList(growable: false);
    final eventOptionCount = eventsWithOptions.fold<int>(
      0,
      (total, event) => total + event.transmissionOptions.length,
    );
    final totalOptions = _channels.length + eventOptionCount;

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
            tooltip: 'Actualizar canales y transmisiones de Agenda',
            icon: const Icon(Icons.refresh_rounded, color: _agendaChannelsBlue),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          LiveSharedPlayerPanel(
            source: _selectedSource,
            emptyMessage: 'Elige un canal de abajo y pulsa PLAY para cargarlo aquí.',
          ),
          Container(
            width: double.infinity,
            color: _agendaChannelsPanel,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'CANALES Y TRANSMISIONES CAPTURADOS DE LA AGENDA',
                  style: TextStyle(
                    color: _agendaChannelsBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_channels.length} canales · $eventOptionCount transmisiones de eventos · $totalOptions opciones',
                  style: const TextStyle(
                    color: _agendaChannelsMuted,
                    fontSize: 10,
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
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: _agendaChannelsBlue,
              backgroundColor: _agendaChannelsPanel,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                children: <Widget>[
                  if (_channels.isNotEmpty) ...<Widget>[
                    const _ChannelSectionHeading(title: 'CANALES DE LA AGENDA'),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 560 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _channels.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.55,
                          ),
                          itemBuilder: (context, index) => _TransmissionOptionTile(
                            option: _channels[index],
                            isPreferred: index == 0,
                            fallbackIndex: index + 1,
                            onPlay: _playOption,
                          ),
                        );
                      },
                    ),
                  ],
                  if (eventsWithOptions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    const _ChannelSectionHeading(title: 'TRANSMISIONES POR EVENTO'),
                    for (final event in eventsWithOptions)
                      Container(
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
                                    Icons.sports_soccer_rounded,
                                    color: _agendaChannelsBlue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      event.title,
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
                                    _eventTime(event.startsAt),
                                    style: const TextStyle(
                                      color: _agendaChannelsMuted,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                              if (event.competition.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  event.competition,
                                  style: const TextStyle(
                                    color: _agendaChannelsMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                              const Divider(color: Color(0xFF193044), height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 560 ? 3 : 2;
                                  final ranked = rankAgendaTransmissionOptions(
                                    event.transmissionOptions,
                                  );
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: ranked.length,
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1.55,
                                    ),
                                    itemBuilder: (context, optionIndex) => _TransmissionOptionTile(
                                      option: ranked[optionIndex],
                                      isPreferred: optionIndex == 0,
                                      fallbackIndex: optionIndex + 1,
                                      onPlay: (option) => _playOption(
                                        option,
                                        eventId: event.id,
                                        subtitle: '${event.competition} · ${event.title}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (_channels.isEmpty && eventsWithOptions.isEmpty)
                    _EmptyAgendaChannels(onOpenAgenda: widget.onOpenAgenda),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playOption(
    AgendaTransmissionOption option, {
    String? eventId,
    String? subtitle,
  }) {
    final source = LivePlayerSource(
      title: option.name,
      url: option.url,
      subtitle: subtitle ?? 'CANALES DEPORTIVOS · ${option.name}',
      eventId: eventId,
      useEmbeddedPage: !isSupportedAuthorizedMediaUrl(option.url),
    );
    setState(() => _selectedSource = source);
  }
}

class _TransmissionOptionTile extends StatelessWidget {
  const _TransmissionOptionTile({
    required this.option,
    required this.isPreferred,
    required this.fallbackIndex,
    required this.onPlay,
  });

  final AgendaTransmissionOption option;
  final bool isPreferred;
  final int fallbackIndex;
  final ValueChanged<AgendaTransmissionOption> onPlay;

  @override
  Widget build(BuildContext context) {
    final hasPopularityMetric = option.popularityScore > 0;
    return Material(
      color: const Color(0xFF0D1118),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onPlay(option),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPreferred
                  ? _agendaChannelsBlue.withAlpha(190)
                  : Colors.white.withAlpha(35),
              width: isPreferred ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: isPreferred ? _agendaChannelsBlue : _agendaChannelsMuted,
                    size: 21,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      isPreferred ? 'CANAL DESTACADO' : 'CANAL ${fallbackIndex}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPreferred ? _agendaChannelsBlue : _agendaChannelsMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                option.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasPopularityMetric ? 'POPULARIDAD PUBLICADA' : 'FUENTE DE AGENDA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _agendaChannelsMuted,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PLAY · REPRODUCIR ARRIBA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _agendaChannelsBlue,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelSectionHeading extends StatelessWidget {
  const _ChannelSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: _agendaChannelsBlue,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      );
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
              'Abre un evento en Agenda y toca una de sus opciones visibles de transmisión. La app guardará el enlace de esa opción aquí.',
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

/// Opens the same public page link shown by the agenda. It does not extract
/// media URLs from iframes or bypass third-party player controls.
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
