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
  List<AgendaChannelEntry> _channels = <AgendaChannelEntry>[];
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
      final channels = await _service.loadChannelsForCurrentDay();
      if (!mounted) return;
      final activeEventIds = channels
          .where((entry) => entry.belongsToEvent)
          .map((entry) => entry.eventId)
          .toSet();
      setState(() {
        _channels = channels;
        if (_selectedSource?.eventId != null &&
            !activeEventIds.contains(_selectedSource!.eventId)) {
          _selectedSource = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Actualizar canales',
            icon: const Icon(Icons.refresh_rounded, color: _agendaChannelsBlue),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          LiveSharedPlayerPanel(
            source: _selectedSource,
            compact: true,
            emptyMessage: 'Elige una transmisión de los eventos de hoy y pulsa PLAY.',
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF071B31), Color(0xFF17101A)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _agendaChannelsBlue.withAlpha(120)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.sports_score_rounded,
                    color: _agendaChannelsBlue, size: 22),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'TRANSMISIONES DE LOS EVENTOS DE HOY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .35,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Fuentes publicadas dentro de cada ficha de la Agenda',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _agendaChannelsMuted, fontSize: 8),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_channels.length}',
                  style: const TextStyle(
                    color: _agendaChannelsBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: _agendaChannelsPanel,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'CANALES DISPONIBLES',
                    style: TextStyle(
                      color: _agendaChannelsBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_channels.length} canales',
                  style: const TextStyle(
                    color: _agendaChannelsMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                children: <Widget>[
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: _agendaChannelsBlue,
                        backgroundColor: Colors.black,
                      ),
                    ),
                  if (_channels.isEmpty)
                    _EmptyAgendaChannels(onOpenAgenda: widget.onOpenAgenda)
                  else ...<Widget>[
                    const _ChannelSectionHeading(title: 'SELECCIONA UN CANAL'),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 560 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _channels.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9,
                            childAspectRatio: 1.55,
                          ),
                          itemBuilder: (context, index) => _TransmissionOptionTile(
                            entry: _channels[index],
                            isPreferred: index == 0,
                            fallbackIndex: index + 1,
                            onPlay: _playOption,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playOption(AgendaChannelEntry entry) {
    final option = entry.option;
    final source = LivePlayerSource(
      title: option.name,
      url: option.url,
      subtitle: entry.eventTitle == null
          ? 'CANALES DEPORTIVOS · ${option.name}'
          : '${entry.eventTitle} · ${option.name}',
      eventId: entry.eventId,
      startAt: entry.startsAt,
      useEmbeddedPage: !isSupportedAuthorizedMediaUrl(option.url),
    );
    setState(() => _selectedSource = source);
  }
}

class _TransmissionOptionTile extends StatelessWidget {
  const _TransmissionOptionTile({
    required this.entry,
    required this.isPreferred,
    required this.fallbackIndex,
    required this.onPlay,
  });

  final AgendaChannelEntry entry;
  final bool isPreferred;
  final int fallbackIndex;
  final ValueChanged<AgendaChannelEntry> onPlay;

  @override
  Widget build(BuildContext context) {
    final option = entry.option;
    final hasPopularityMetric = option.popularityScore > 0;
    return Material(
      color: const Color(0xFF0D1118),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onPlay(entry),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF121B29), Color(0xFF080B11)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPreferred
                  ? _agendaChannelsBlue.withAlpha(190)
                  : Colors.white.withAlpha(35),
              width: isPreferred ? 1.3 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _agendaChannelsBlue.withAlpha(isPreferred ? 28 : 10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
              if (entry.eventTitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  entry.eventTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _agendaChannelsMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              Text(
                entry.eventTitle != null
                    ? 'VINCULADO A UN EVENTO DE HOY'
                    : (hasPopularityMetric ? 'POPULARIDAD PUBLICADA' : 'FUENTE DE AGENDA'),
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
              'TODAVÍA NO HAY TRANSMISIONES CAPTURADAS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Las fuentes HTTPS asociadas a cada evento aparecerán aquí cuando la Agenda termine de cargar. Las entradas que solo abren la propia Agenda se excluyen automáticamente.',
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
