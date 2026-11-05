import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'iptv_extractor_player_screen.dart';

const Color _sportsBg = Color(0xFF030814);
const Color _sportsPanel = Color(0xFF071326);
const Color _sportsPanel2 = Color(0xFF0B1B31);
const Color _sportsLine = Color(0xFF123D65);
const Color _sportsCyan = Color(0xFF00E5FF);
const Color _sportsGreen = Color(0xFF39FF9C);
const Color _sportsPink = Color(0xFFFF28CF);
const Color _sportsMuted = Color(0xFFA9BDD6);

class SportsChannelsScreen extends StatefulWidget {
  const SportsChannelsScreen({
    super.key,
    this.initialChannel,
  });

  final IptvExtractedChannel? initialChannel;

  @override
  State<SportsChannelsScreen> createState() => _SportsChannelsScreenState();
}

class _SportsChannelsScreenState extends State<SportsChannelsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<IptvExtractedChannel> _channels = <IptvExtractedChannel>[];
  Set<String> _favoriteIds = <String>{};
  IptvExtractedChannel? _selectedChannel;
  VideoPlayerController? _controller;
  bool _loadingLibrary = true;
  bool _loadingVideo = false;
  bool _showFavoritesOnly = false;
  bool _fullscreen = false;
  String _query = '';
  String? _libraryError;
  String? _playerError;
  int _playGeneration = 0;
  int _libraryGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
    _searchController.addListener(_updateSearch);
    iptvSportsCatalogVersion.addListener(_handleCatalogChanged);
    _loadLibrary();
    if (_selectedChannel != null) {
      _playChannel(_selectedChannel!);
    }
  }

  @override
  void didUpdateWidget(covariant SportsChannelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialChannel;
    if (next != null &&
        (oldWidget.initialChannel?.id != next.id ||
            oldWidget.initialChannel?.url != next.url)) {
      _playChannel(next);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearch);
    iptvSportsCatalogVersion.removeListener(_handleCatalogChanged);
    _searchController.dispose();
    _controller?.removeListener(_controllerChanged);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _updateSearch() {
    if (mounted) setState(() => _query = _searchController.text.trim());
  }

  void _handleCatalogChanged() {
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final generation = ++_libraryGeneration;
    try {
      final values = await Future.wait<Object>(<Future<Object>>[
        loadIptvStudioSportsChannels(),
        loadIptvStudioFavoriteIds(),
      ]);
      final loaded = values[0] as List<IptvExtractedChannel>;
      final favorites = values[1] as Set<String>;
      final unique = <String, IptvExtractedChannel>{};
      for (final channel in loaded) {
        unique.putIfAbsent(channel.id, () => channel);
      }
      final sorted = unique.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final selected = _selectedChannel;
      if (selected != null &&
          !sorted.any((channel) => channel.url == selected.url)) {
        sorted.insert(0, selected);
      }
      if (!mounted || generation != _libraryGeneration) return;
      setState(() {
        _channels = sorted;
        _favoriteIds = favorites;
        _loadingLibrary = false;
        _libraryError = sorted.isEmpty
            ? 'Aún no agregaste canales. Entra al menú de Damián APK y usa “Agregar a Canales deportivos”.'
            : null;
      });
    } catch (error) {
      if (!mounted || generation != _libraryGeneration) return;
      setState(() {
        _loadingLibrary = false;
        _libraryError = 'No se pudo cargar la selección de canales: ' + error.toString();
      });
    }
  }

  List<IptvExtractedChannel> get _visibleChannels {
    final query = _query.trim().toLowerCase();
    return _channels.where((channel) {
      if (_showFavoritesOnly && !_favoriteIds.contains(channel.id)) return false;
      if (query.isEmpty) return true;
      return (channel.name + ' ' + channel.group + ' ' + channel.tvgId)
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);
  }

  VideoFormat _formatHint(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return VideoFormat.hls;
    if (path.endsWith('.mpd')) return VideoFormat.dash;
    return VideoFormat.other;
  }

  Future<void> _playChannel(IptvExtractedChannel channel) async {
    final generation = ++_playGeneration;
    final old = _controller;
    _controller = null;
    old?.removeListener(_controllerChanged);
    await old?.dispose();
    if (!mounted || generation != _playGeneration) return;

    setState(() {
      _selectedChannel = channel;
      _loadingVideo = true;
      _playerError = null;
    });

    VideoPlayerController? next;
    try {
      next = VideoPlayerController.networkUrl(
        Uri.parse(channel.url),
        formatHint: _formatHint(channel.url),
        httpHeaders: const <String, String>{
          'User-Agent': 'DeporteTotal360-IPTV/1.0',
        },
      );
      // En HLS/DASH el motor nativo elige automáticamente la calidad
      // disponible cuando la señal publica variantes adaptativas.
      await next.initialize().timeout(const Duration(seconds: 22));
      if (!mounted || generation != _playGeneration) {
        await next.dispose();
        return;
      }
      _controller = next;
      next.addListener(_controllerChanged);
      await next.play();
      if (mounted && generation == _playGeneration) {
        setState(() => _loadingVideo = false);
      }
    } catch (error) {
      await next?.dispose();
      if (!mounted || generation != _playGeneration) return;
      setState(() {
        _loadingVideo = false;
        _playerError =
            'No se pudo reproducir esta señal. Comprueba que esté activa y permita reproducción directa. ' +
                error.toString();
      });
    }
  }

  void _controllerChanged() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value != null && value.hasError && _playerError == null) {
      setState(() => _playerError =
          value.errorDescription ?? 'Error en la transmisión.');
    }
  }

  Future<void> _toggleFavorite(IptvExtractedChannel channel) async {
    setState(() {
      if (!_favoriteIds.add(channel.id)) {
        _favoriteIds.remove(channel.id);
      }
    });
    await saveIptvStudioFavoriteIds(_favoriteIds);
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

  Future<void> _copySelectedUrl() async {
    final channel = _selectedChannel;
    if (channel == null) return;
    await Clipboard.setData(ClipboardData(text: channel.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL directa del canal copiada.')),
    );
  }

  Future<void> _copySelectedIdentifierUrl() async {
    final channel = _selectedChannel;
    if (channel == null) return;
    await Clipboard.setData(ClipboardData(text: channel.identificationUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Identificador copiado: ' + channel.identificationUrl)),
    );
  }

  Widget _buildPlayer() {
    final controller = _controller;
    final value = controller?.value;
    final initialized = value?.isInitialized == true;
    final screenSize = MediaQuery.sizeOf(context);
    final naturalHeight = screenSize.width / (16 / 9);
    final compactHeight = screenSize.height * 0.33;
    final playerHeight = _fullscreen
        ? screenSize.height
        : (naturalHeight < compactHeight ? naturalHeight : compactHeight);
    return SizedBox(
      width: double.infinity,
      height: playerHeight,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (initialized)
              Center(
                child: AspectRatio(
                  aspectRatio: value!.aspectRatio,
                  child: VideoPlayer(controller!),
                ),
              )
            else if (_loadingVideo)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(color: _sportsCyan),
                    SizedBox(height: 10),
                    Text('Conectando con la señal…',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              )
            else if (_playerError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _playerError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.live_tv_rounded, color: _sportsCyan, size: 46),
                    SizedBox(height: 8),
                    Text('Selecciona un canal para reproducirlo',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            if (initialized)
              Positioned(
                left: 8,
                bottom: 7,
                child: IconButton.filled(
                  tooltip: value!.isPlaying ? 'Pausar' : 'Reproducir',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withAlpha(170),
                    foregroundColor: _sportsCyan,
                  ),
                  onPressed: () {
                    if (value!.isPlaying) {
                      controller!.pause();
                    } else {
                      controller!.play();
                    }
                    setState(() {});
                  },
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            Positioned(
              right: 8,
              bottom: 7,
              child: IconButton.filled(
                tooltip: _fullscreen ? 'Salir de pantalla completa' : 'Pantalla completa',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(170),
                  foregroundColor: _sportsGreen,
                ),
                onPressed: _toggleFullscreen,
                icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
              ),
            ),
            Positioned(
              left: 12,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(175),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _sportsGreen.withAlpha(170)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.auto_awesome, color: _sportsGreen, size: 12),
                    SizedBox(width: 5),
                    Text('AUTO', style: TextStyle(
                      color: _sportsGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelTile(IptvExtractedChannel channel) {
    final selected = _selectedChannel?.url == channel.url;
    final favorite = _favoriteIds.contains(channel.id);
    return Material(
      color: selected ? _sportsPanel2 : _sportsPanel,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _playChannel(channel),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? _sportsCyan : _sportsLine,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.black.withAlpha(45),
                  padding: const EdgeInsets.all(9),
                  child: channel.logo.isNotEmpty
                      ? Image.network(
                          channel.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.live_tv_rounded,
                            color: _sportsCyan,
                            size: 32,
                          ),
                        )
                      : const Icon(Icons.live_tv_rounded,
                          color: _sportsCyan, size: 32),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 5),
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 7, right: 7, bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      favorite ? Icons.favorite : Icons.play_circle_fill,
                      color: favorite ? _sportsPink : _sportsGreen,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        favorite ? 'FAVORITO' : (channel.group.isEmpty ? 'EN VIVO' : channel.group),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _sportsMuted, fontSize: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleChannels;
    return Scaffold(
      backgroundColor: _sportsBg,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: _sportsBg,
              title: const Text(
                'CANALES DEPORTIVOS',
                style: TextStyle(
                  color: _sportsCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: .5,
                ),
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Actualizar listas',
                  onPressed: _loadingLibrary ? null : _loadLibrary,
                  icon: const Icon(Icons.refresh_rounded, color: _sportsGreen),
                ),
              ],
            ),
      body: SafeArea(
        child: _fullscreen
            ? Center(child: _buildPlayer())
            : Column(
                children: <Widget>[
                  _buildPlayer(),
                  if (_selectedChannel != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 5),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _selectedChannel!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Resolución automática · según la señal disponible',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _sportsGreen, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: _favoriteIds.contains(_selectedChannel!.id)
                                ? 'Quitar de favoritos'
                                : 'Agregar a favoritos',
                            onPressed: () => _toggleFavorite(_selectedChannel!),
                            icon: Icon(
                              _favoriteIds.contains(_selectedChannel!.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _sportsPink,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copiar URL directa del canal',
                            onPressed: _copySelectedUrl,
                            icon: const Icon(Icons.copy_rounded, color: _sportsCyan),
                          ),
                          IconButton(
                            tooltip: 'Copiar URL identificadora',
                            onPressed: _copySelectedIdentifierUrl,
                            icon: const Icon(Icons.link_rounded, color: _sportsGreen),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar canal…',
                        prefixIcon: const Icon(Icons.search_rounded, color: _sportsCyan),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar búsqueda',
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: _sportsPanel,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: _sportsLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: _sportsLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: _sportsCyan),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
                    child: Row(
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('TODOS'),
                          selected: !_showFavoritesOnly,
                          onSelected: (_) => setState(() => _showFavoritesOnly = false),
                          selectedColor: _sportsCyan.withAlpha(50),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('♥ FAVORITOS'),
                          selected: _showFavoritesOnly,
                          onSelected: (_) => setState(() => _showFavoritesOnly = true),
                          selectedColor: _sportsPink.withAlpha(50),
                        ),
                        const Spacer(),
                        Text(
                          visible.length.toString() + ' canales',
                          style: const TextStyle(color: _sportsMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loadingLibrary
                        ? const Center(
                            child: CircularProgressIndicator(color: _sportsCyan),
                          )
                        : visible.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _showFavoritesOnly
                                        ? 'Todavía no tienes canales favoritos.'
                                        : (_channels.isEmpty
                                            ? (_libraryError ?? 'Todavía no agregaste canales desde el menú de Damián APK.')
                                            : 'No hay canales que coincidan con la búsqueda.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: _sportsMuted),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 9,
                                  mainAxisSpacing: 9,
                                  childAspectRatio: 1.38,
                                ),
                                itemCount: visible.length,
                                itemBuilder: (_, index) =>
                                    _buildChannelTile(visible[index]),
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}
