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
      final channels = await _service.loadCapturedChannels();
      if (!mounted) return;
      channels.sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _channels = channels;
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
            emptyMessage: 'Elige un canal de abajo y pulsa PLAY para reproducirlo aquí.',
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
                            option: _channels[index],
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

  void _playOption(AgendaTransmissionOption option) {
    final source = LivePlayerSource(
      title: option.name,
      url: option.url,
      subtitle: 'CANALES DEPORTIVOS · ${option.name}',
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
              'Abre Agenda y espera a que cargue: las opciones de canales publicadas se guardarán automáticamente y aparecerán aquí. Las transmisiones vinculadas a cada evento se mostrarán en su sección cuando estén disponibles.',
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
