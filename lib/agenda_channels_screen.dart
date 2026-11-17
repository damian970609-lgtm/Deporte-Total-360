import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'agenda_web_screen.dart';

import 'agenda_live_service.dart';

const Color _agendaChannelsBg = Color(0xFF000000);
const Color _agendaChannelsPanel = Color(0xFF07090D);
const Color _agendaChannelsBlue = Color(0xFF00A3FF);
const Color _agendaChannelsMuted = Color(0xFFEAF0F8);
const Color _agendaChannelsGreen = Color(0xFF39FF14);

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
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  List<AgendaChannelReference> _channels = <AgendaChannelReference>[];
  bool _loading = true;
  bool _usingEventSources = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final published = await _service.loadCapturedChannels();
      final events = await _service.loadCapturedEvents();
      final byName = <String, AgendaChannelReference>{
        for (final channel in published) channel.id: channel,
      };

      // Respaldo: muestra las opciones visibles de los partidos mientras la
      // página todavía no haya publicado una sección global de canales.
      final usingEventSources = published.isEmpty;
      if (usingEventSources) {
        for (final event in events) {
          for (final option in event.transmissionOptions) {
            final id = normalizeAgendaChannelReference(option.name);
            if (id.isEmpty || byName.containsKey(id)) continue;
            byName[id] = AgendaChannelReference(
              id: id,
              name: option.name,
              url: option.url,
              order: option.order,
              popularityScore: option.popularityScore,
            );
          }
        }
      }

      final channels = byName.values.toList(growable: false)
        ..sort((a, b) {
          final score = b.popularityScore.compareTo(a.popularityScore);
          if (score != 0) return score;
          final order = a.order.compareTo(b.order);
          if (order != 0) return order;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _usingEventSources = usingEventSources;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo actualizar el catálogo. Vuelve a intentarlo.';
      });
      debugPrint('Error al cargar los canales de Agenda: $error');
    }
  }

  List<AgendaChannelReference> get _filteredChannels {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _channels;
    return _channels.where((channel) =>
      channel.name.toLowerCase().contains(query)
    ).toList(growable: false);
  }

  Future<void> _openChannel(AgendaChannelReference channel) async {
    if (!isSafeAgendaTransmissionUrl(channel.url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La página del canal no es un enlace HTTPS válido.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgendaTransmissionWebView(
          title: channel.name,
          url: channel.url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleChannels = _filteredChannels;
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
            tooltip: 'Actualizar canales de Fútbol Libre',
            icon: const Icon(Icons.refresh_rounded, color: _agendaChannelsBlue),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
          Container(
            width: double.infinity,
            color: _agendaChannelsPanel,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'CANALES PUBLICADOS POR FÚTBOL LIBRE',
                  style: TextStyle(
                    color: _agendaChannelsBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _usingEventSources
                      ? '${_channels.length} opciones encontradas en las fichas de partidos'
                      : '${_channels.length} canales encontrados en la sección de canales de la web',
                  style: const TextStyle(
                    color: _agendaChannelsMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar canal...',
                    prefixIcon: const Icon(Icons.search, color: _agendaChannelsBlue),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close, color: _agendaChannelsMuted),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF0D1118),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF193044)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF193044)),
                    ),
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
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFFB4C0), fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: visibleChannels.isEmpty
                ? _EmptyAgendaChannels(
                    loading: _loading,
                    onOpenAgenda: widget.onOpenAgenda,
                    onRefresh: _refresh,
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: _agendaChannelsBlue,
                    backgroundColor: _agendaChannelsPanel,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
                      itemCount: visibleChannels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final channel = visibleChannels[index];
                        final hasPopularityMetric = channel.popularityScore > 0;
                        return Container(
                          decoration: BoxDecoration(
                            color: _agendaChannelsPanel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _agendaChannelsBlue.withAlpha(100),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 4,
                            ),
                            leading: _ChannelLogo(url: channel.logoUrl),
                            title: Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              hasPopularityMetric
                                  ? 'POPULARIDAD PUBLICADA: ${channel.popularityScore}'
                                  : 'REPRODUCTOR ORIGINAL DE LA WEB',
                              maxLines: 1,
                              style: const TextStyle(
                                color: _agendaChannelsMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: _agendaChannelsGreen,
                              size: 25,
                            ),
                            onTap: () => _openChannel(channel),
                          ),
                        );
                      },
                    ),
                  ),
          ),
            ],
          ),
          if (_channels.isEmpty && !_loading)
            const Offstage(
              offstage: true,
              child: SizedBox.expand(
                child: AgendaWebScreen(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const CircleAvatar(
        backgroundColor: Color(0xFF0D1118),
        child: Icon(Icons.live_tv_rounded, color: _agendaChannelsBlue),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 42,
        height: 42,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.live_tv_rounded, color: _agendaChannelsBlue),
        ),
      ),
    );
  }
}

class _EmptyAgendaChannels extends StatelessWidget {
  const _EmptyAgendaChannels({
    required this.loading,
    required this.onOpenAgenda,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onOpenAgenda;
  final VoidCallback onRefresh;

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
            Text(
              loading
                  ? 'CARGANDO CANALES DE LA WEB'
                  : 'TODAVÍA NO HAY CANALES CAPTURADOS',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'La APK toma los nombres, logotipos y páginas de canal que la web publica. Abre la Agenda para que se actualicen las referencias.',
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
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ACTUALIZAR CANALES'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre la página HTTPS publicada por la web y mantiene su reproductor,
/// iframe y controles originales. La APK no extrae enlaces internos del vídeo.
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
  bool _loading = true;

  InAppWebViewController? _controller;

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await controller.reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo recargar el reproductor.';
      });
      debugPrint('Error al recargar el reproductor del canal: $error');
    }
  }

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
        actions: <Widget>[
          IconButton(
            tooltip: 'Recargar reproductor',
            onPressed: !safe || _controller == null ? null : _reload,
            icon: const Icon(Icons.refresh_rounded, color: _agendaChannelsBlue),
          ),
        ],
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
                  onWebViewCreated: (controller) {
                    if (mounted) setState(() => _controller = controller);
                  },
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
                  onLoadStart: (controller, url) {
                    if (mounted) setState(() {
                      _loading = true;
                      _error = null;
                    });
                  },
                  onLoadStop: (controller, url) {
                    if (mounted) setState(() => _loading = false);
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame == false || !mounted) return;
                    setState(() {
                      _loading = false;
                      _error = 'No se pudo abrir esta página. Comprueba la conexión.';
                    });
                  },
                ),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _agendaChannelsBlue,
                    ),
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
