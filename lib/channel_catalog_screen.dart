import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import 'channel_catalog_service.dart';

const Color _channelBg = Color(0xFF030814);
const Color _channelPanel = Color(0xFF071326);
const Color _channelPanel2 = Color(0xFF0B1B31);
const Color _channelLine = Color(0xFF123D65);
const Color _channelCyan = Color(0xFF00E5FF);
const Color _channelPink = Color(0xFFFF28CF);
const Color _channelGreen = Color(0xFF39FF9C);
const Color _channelYellow = Color(0xFFFFD600);
const Color _channelMuted = Color(0xFFA9BDD6);
const String _channelFavoritesKey = 'dt360_channel_catalog_favorites_v1';

const String _defaultSportsPlaylistUrl =
    'https://iptv-org.github.io/iptv/categories/sports.m3u';

class _SuggestedSportsPlaylist {
  const _SuggestedSportsPlaylist({
    required this.label,
    required this.url,
    required this.description,
  });

  final String label;
  final String url;
  final String description;
}

const List<_SuggestedSportsPlaylist> _suggestedSportsPlaylists = <
    _SuggestedSportsPlaylist>[
  _SuggestedSportsPlaylist(
    label: 'IPTV-org · Deportes',
    url: _defaultSportsPlaylistUrl,
    description: 'Fuente principal · categoría deportiva pública',
  ),
  _SuggestedSportsPlaylist(
    label: 'IPTV Validated · Deportes',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/categories/sports.m3u',
    description: 'Lista comunitaria con comprobación diaria de señales',
  ),
  _SuggestedSportsPlaylist(
    label: 'Free-TV · Lista pública',
    url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8',
    description: 'Selección pública general; no es exclusiva de deportes',
  ),
];

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

class ChannelLanguageBadge extends StatelessWidget {
  const ChannelLanguageBadge({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final label = channelLanguageDisplayLabel(language);
    if (label == null) return const SizedBox.shrink();
    final spanish = language == 'es';
    final accent = spanish ? _channelGreen : _channelCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withAlpha(130)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ChannelCatalogScreen extends StatefulWidget {
  const ChannelCatalogScreen({super.key});

  @override
  State<ChannelCatalogScreen> createState() => _ChannelCatalogScreenState();
}

class _ChannelCatalogScreenState extends State<ChannelCatalogScreen> {
  final ChannelCatalogService _service = channelCatalogService;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _favorites = <String>{};
  List<SportsChannel> _channels = <SportsChannel>[];
  SportsChannel? _selectedChannel;
  Timer? _searchDebounce;
  int _catalogRequestId = 0;
  int _nextCatalogOffset = 0;
  int _catalogTotal = 0;
  bool _hasMoreChannels = false;
  bool _loadingMoreChannels = false;
  String? _loadMoreError;
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  String? _signedInEmail;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleCatalogScroll);
    unawaited(_loadLocalFavorites());
    unawaited(_loadChannels());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_handleCatalogScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(prefs.getStringList(_channelFavoritesKey) ?? <String>[]);
      });
    } catch (_) {}
  }

  Future<void> _saveLocalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _channelFavoritesKey,
        _favorites.toList(growable: false),
      );
    } catch (_) {}
  }

  Future<void> _loadChannels() async {
    _searchDebounce?.cancel();
    final requestId = ++_catalogRequestId;
    final search = _searchController.text.trim();
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMoreChannels = false;
        _loadMoreError = null;
        _error = null;
        _channels = <SportsChannel>[];
        _nextCatalogOffset = 0;
        _catalogTotal = 0;
        _hasMoreChannels = false;
      });
    }
    try {
      final page = await _service.fetchPublicChannelPage(
        search: search,
        offset: 0,
      );
      if (!mounted || requestId != _catalogRequestId) return;
      final previousId = _selectedChannel?.id;
      setState(() {
        _channels = page.channels;
        _catalogTotal = page.total;
        _nextCatalogOffset = page.offset + page.channels.length;
        _hasMoreChannels = page.hasMore;
        _selectedChannel = _firstOrNull(
          page.channels.where((item) => item.id == previousId),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _catalogRequestId) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _handleSearchChanged(String _) {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_loadChannels()),
    );
  }

  void _handleCatalogScroll() {
    if (!_scrollController.hasClients || _loadMoreError != null) return;
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadMoreChannels());
    }
  }

  Future<void> _loadMoreChannels() async {
    if (_loading || _loadingMoreChannels || !_hasMoreChannels) return;
    final requestId = _catalogRequestId;
    final offset = _nextCatalogOffset;
    final search = _searchController.text.trim();
    setState(() {
      _loadingMoreChannels = true;
      _loadMoreError = null;
    });
    try {
      final page = await _service.fetchPublicChannelPage(
        search: search,
        offset: offset,
      );
      if (!mounted || requestId != _catalogRequestId) return;
      if (page.channels.isEmpty && page.hasMore) {
        setState(() {
          _loadMoreError =
              'El servidor no entregó más canales. Pulsa para volver a intentarlo.';
        });
        return;
      }
      setState(() {
        final knownIds = _channels.map((channel) => channel.id).toSet();
        _channels = <SportsChannel>[
          ..._channels,
          ...page.channels.where((channel) => knownIds.add(channel.id)),
        ];
        _catalogTotal = page.total;
        _nextCatalogOffset = page.offset + page.channels.length;
        _hasMoreChannels = page.hasMore;
      });
    } catch (error) {
      if (!mounted || requestId != _catalogRequestId) return;
      setState(() => _loadMoreError = error.toString());
    } finally {
      if (mounted && requestId == _catalogRequestId) {
        setState(() => _loadingMoreChannels = false);
      }
    }
  }

  Future<void> _syncGoogleFavorites() async {
    setState(() => _syncing = true);
    try {
      final email = await _service.signIn();
      final remote = await _service.fetchFavorites();
      if (remote.isEmpty && _favorites.isNotEmpty) {
        await _service.saveFavorites(_favorites);
      } else {
        _favorites
          ..clear()
          ..addAll(remote);
        await _saveLocalFavorites();
      }
      if (!mounted) return;
      setState(() => _signedInEmail = email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favoritos sincronizados con tu cuenta Google.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _toggleFavorite(SportsChannel channel) async {
    setState(() {
      if (!_favorites.add(channel.id)) _favorites.remove(channel.id);
    });
    await _saveLocalFavorites();
    if (_service.signedInEmail != null) {
      try {
        await _service.saveFavorites(_favorites);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              'El favorito quedó guardado en este teléfono. No se pudo sincronizar: ' +
                  error.toString(),
            )),
          );
        }
      }
    }
  }

  List<SportsChannel> get _filteredChannels {
    final query = _searchController.text.trim().toLowerCase();
    final rows = _channels.where((channel) {
      if (query.isEmpty) return true;
      return (channel.name + ' ' + channel.groupTitle)
          .toLowerCase()
          .contains(query);
    }).toList();
    rows.sort((a, b) {
      final favoriteOrder = (_favorites.contains(b.id) ? 1 : 0)
          .compareTo(_favorites.contains(a.id) ? 1 : 0);
      if (favoriteOrder != 0) return favoriteOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return rows;
  }

  Widget _background(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.45,
          colors: <Color>[
            Color(0xFF102B50),
            _channelBg,
            Color(0xFF02050C),
          ],
          stops: <double>[0, 0.56, 1],
        ),
      ),
      child: child,
    );
  }

  Widget _sectionHeading(String title, {IconData icon = Icons.sports_soccer}) {
    return Row(
      children: <Widget>[
        Icon(icon, color: _channelCyan, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.65,
            ),
          ),
        ),
      ],
    );
  }

  Widget _channelCard(SportsChannel channel, int index) {
    final favorite = _favorites.contains(channel.id);
    final selected = _selectedChannel?.id == channel.id;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() => _selectedChannel = channel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _channelPanel.withAlpha(245),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? _channelCyan : _channelLine,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (selected ? _channelCyan : _channelPink).withAlpha(18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 23,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _channelCyan.withAlpha(22),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _channelCyan.withAlpha(100)),
                  ),
                  child: Text(
                    (index + 1).toString(),
                    style: const TextStyle(
                      color: _channelCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                ChannelLanguageBadge(language: channel.language),
                const SizedBox(width: 5),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 31,
                    height: 31,
                  ),
                  onPressed: () => _toggleFavorite(channel),
                  icon: Icon(
                    favorite ? Icons.favorite_rounded : Icons.favorite_border,
                    color: favorite ? _channelPink : _channelMuted,
                    size: 18,
                  ),
                  tooltip: favorite ? 'Quitar favorito' : 'Guardar favorito',
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _ChannelLogo(channel: channel, size: 42),
              ),
            ),
            Text(
              channel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              channel.groupTitle.isEmpty ? 'DEPORTES' : channel.groupTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _channelMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = _filteredChannels;
    return Scaffold(
      backgroundColor: _channelBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF041021),
        title: const Text(
          'CANALES DEPORTIVOS',
          style: TextStyle(
            color: _channelCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.7,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _signedInEmail == null
                ? 'Sincronizar favoritos con Google'
                : 'Favoritos sincronizados',
            onPressed: _syncing ? null : _syncGoogleFavorites,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _channelCyan,
                    ),
                  )
                : Icon(
                    _signedInEmail == null
                        ? Icons.cloud_sync_rounded
                        : Icons.cloud_done_rounded,
                    color: _channelGreen,
                  ),
          ),
        ],
      ),
      body: _background(
        RefreshIndicator(
          color: _channelCyan,
          backgroundColor: _channelPanel,
          onRefresh: _loadChannels,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionHeading(
                        _selectedChannel == null
                            ? 'REPRODUCTOR DEPORTIVO'
                            : _selectedChannel!.name.toUpperCase(),
                        icon: Icons.play_circle_fill_rounded,
                      ),
                      const SizedBox(height: 9),
                      ChannelInlinePlayer(
                        key: ValueKey<String>(
                          _selectedChannel?.id ?? 'channel-player-empty',
                        ),
                        channel: _selectedChannel,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _sectionHeading(
                              'CATÁLOGO DE CANALES',
                              icon: Icons.grid_view_rounded,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _channelCyan.withAlpha(18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _channelCyan.withAlpha(90),
                              ),
                            ),
                            child: Text(
                              channels.length.toString() + ' / ' +
                                  _catalogTotal.toString(),
                              style: const TextStyle(
                                color: _channelCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: _handleSearchChanged,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar canal deportivo...',
                          hintStyle: const TextStyle(
                            color: _channelMuted,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _channelCyan,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _handleSearchChanged('');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _channelMuted,
                                  ),
                                ),
                          filled: true,
                          fillColor: _channelPanel,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: _channelLine,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(
                              color: _channelCyan,
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_signedInEmail != null)
                        Text(
                          'Favoritos sincronizados: ' + _signedInEmail!,
                          style: const TextStyle(
                            color: _channelGreen,
                            fontSize: 9,
                          ),
                        )
                      else
                        const Text(
                          'Inicia sesión con Google para recuperar tus favoritos al reinstalar.',
                          style: TextStyle(
                            color: _channelMuted,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _channelCyan),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: _channelPink,
                            size: 39,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _channelMuted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadChannels,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('RECARGAR'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (channels.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Todavía no hay canales publicados.',
                      style: TextStyle(color: _channelMuted),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(13, 2, 13, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _channelCard(channels[index], index),
                      childCount: channels.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
                    ),
                  ),
                ),
              if (_loadingMoreChannels)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 28),
                    child: Center(
                      child: CircularProgressIndicator(color: _channelCyan),
                    ),
                  ),
                )
              else if (_loadMoreError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _loadMoreChannels,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('REINTENTAR CARGA'),
                      ),
                    ),
                  ),
                )
              else if (_hasMoreChannels)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _loadMoreChannels,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('CARGAR MÁS CANALES'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({
    required this.channel,
    this.size = 42,
  });

  final SportsChannel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(channel.logoUrl);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          channel.logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            _channelCyan.withAlpha(25),
            _channelPink.withAlpha(22),
          ],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _channelCyan.withAlpha(100)),
      ),
      child: const Icon(
        Icons.sports_soccer_rounded,
        color: _channelCyan,
        size: 25,
      ),
    );
  }
}

class ChannelInlinePlayer extends StatefulWidget {
  const ChannelInlinePlayer({
    super.key,
    required this.channel,
  });

  final SportsChannel? channel;

  @override
  State<ChannelInlinePlayer> createState() => _ChannelInlinePlayerState();
}

class _ChannelInlinePlayerState extends State<ChannelInlinePlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;
  List<VideoTrack> _tracks = <VideoTrack>[];

  @override
  void initState() {
    super.initState();
    if (widget.channel != null) unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant ChannelInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel?.id != widget.channel?.id) {
      unawaited(_initialize());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleVideoChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _handleVideoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    final previous = _controller;
    _controller = null;
    previous?.removeListener(_handleVideoChanged);
    await previous?.dispose();
    if (!mounted) return;

    final channel = widget.channel;
    if (channel == null) {
      setState(() {
        _loading = false;
        _error = null;
        _tracks = <VideoTrack>[];
      });
      return;
    }

    final uri = Uri.tryParse(channel.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !(uri.path.toLowerCase().endsWith('.m3u8') ||
            uri.path.toLowerCase().endsWith('.mp4') ||
            uri.path.toLowerCase().endsWith('.ts'))) {
      setState(() {
        _loading = false;
        _error = 'La fuente no es un enlace HLS, MP4 o MPEG-TS directo seguro.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _tracks = <VideoTrack>[];
    });

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1);
      if (controller.isVideoTrackSupportAvailable()) {
        try {
          await controller.selectVideoTrack(null);
          _tracks = (await controller.getVideoTracks()).toList()
            ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
        } catch (_) {
          _tracks = <VideoTrack>[];
        }
      }
      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handleVideoChanged);
      setState(() => _loading = false);
      await controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo reproducir esta señal: ' + error.toString();
        });
      }
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    final channel = widget.channel;
    if (controller == null || channel == null ||
        !controller.value.isInitialized) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ChannelFullscreenScreen(
          controller: controller,
          title: channel.name,
          tracks: _tracks,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      height: 225,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _channelCyan.withAlpha(150)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: _channelCyan.withAlpha(20), blurRadius: 18),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (controller != null && controller.value.isInitialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            )
          else
            const Center(
              child: Icon(
                Icons.live_tv_rounded,
                color: _channelCyan,
                size: 50,
              ),
            ),
          if (controller != null && controller.value.isInitialized)
            _ChannelPlayerSurface(
              controller: controller,
              title: widget.channel?.name ?? 'Canales deportivos',
              tracks: _tracks,
              onFullscreen: _openFullscreen,
              fullscreen: false,
            )
          else if (_loading)
            const Center(
              child: CircularProgressIndicator(color: _channelCyan),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: _channelCyan,
                    size: 43,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error ?? 'Selecciona un canal para reproducir',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _channelMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (_error != null)
                    TextButton(
                      onPressed: _initialize,
                      child: const Text('REINTENTAR'),
                    ),
                ],
              ),
            ),
          if (controller?.value.isBuffering == true)
            const Positioned(
              right: 12,
              top: 12,
              child: SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _channelCyan,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelPlayerSurface extends StatefulWidget {
  const _ChannelPlayerSurface({
    required this.controller,
    required this.title,
    required this.tracks,
    required this.onFullscreen,
    required this.fullscreen,
    this.onExitFullscreen,
  });

  final VideoPlayerController controller;
  final String title;
  final List<VideoTrack> tracks;
  final VoidCallback onFullscreen;
  final bool fullscreen;
  final VoidCallback? onExitFullscreen;

  @override
  State<_ChannelPlayerSurface> createState() => _ChannelPlayerSurfaceState();
}

class _ChannelPlayerSurfaceState extends State<_ChannelPlayerSurface> {
  Timer? _hideTimer;
  Timer? _gestureTimer;
  bool _showControls = true;
  bool _locked = false;
  bool _adjustingBrightness = false;
  bool _gestureReady = false;
  double _brightness = 0.65;
  double _volume = 0.65;
  String? _gestureLabel;
  String? _qualityId;

  @override
  void initState() {
    super.initState();
    VolumeController.instance.showSystemUI = false;
    unawaited(_readSystemLevels());
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _gestureTimer?.cancel();
    super.dispose();
  }

  Future<void> _readSystemLevels() async {
    try {
      _brightness = await ScreenBrightness.instance.application;
    } catch (_) {}
    try {
      _volume = await VolumeController.instance.getVolume();
    } catch (_) {}
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.controller.value.isPlaying || _locked) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showAndSchedule() {
    if (!mounted) return;
    setState(() => _showControls = true);
    _scheduleHide();
  }

  void _surfaceTap() {
    if (_locked) {
      setState(() {
        _locked = false;
        _showControls = true;
      });
      _scheduleHide();
      return;
    }
    if (_showControls) {
      setState(() => _showControls = false);
      _hideTimer?.cancel();
    } else {
      _showAndSchedule();
    }
  }

  void _dragStart(DragStartDetails details) {
    if (_locked) return;
    final width = MediaQuery.sizeOf(context).width;
    _adjustingBrightness = details.localPosition.dx < width / 2;
    _gestureReady = true;
    _gestureLabel = _adjustingBrightness ? 'BRILLO' : 'VOLUMEN';
    _showAndSchedule();
    unawaited(_readSystemLevels());
    setState(() {});
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_locked || !_gestureReady) return;
    final height = MediaQuery.sizeOf(context).height;
    final delta = -(details.delta.dy / height) * 1.25;
    if (_adjustingBrightness) {
      _brightness = (_brightness + delta).clamp(0.05, 1.0).toDouble();
      unawaited(ScreenBrightness.instance
          .setApplicationScreenBrightness(_brightness));
      _gestureLabel = 'BRILLO ' + (_brightness * 100).round().toString() + '%';
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0).toDouble();
      unawaited(VolumeController.instance.setVolume(_volume));
      _gestureLabel = 'VOLUMEN ' + (_volume * 100).round().toString() + '%';
    }
    _gestureTimer?.cancel();
    _gestureTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _gestureLabel = null);
    });
    setState(() {});
  }

  void _dragEnd(DragEndDetails details) {
    _gestureReady = false;
    _scheduleHide();
  }

  Future<void> _togglePlayback() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    if (mounted) _showAndSchedule();
  }

  Future<void> _selectQuality(String value) async {
    try {
      if (value == 'auto') {
        await widget.controller.selectVideoTrack(null);
        _qualityId = null;
      } else {
        final track = _firstOrNull(widget.tracks.where((item) => item.id == value));
        if (track != null) {
          await widget.controller.selectVideoTrack(track);
          _qualityId = track.id;
        }
      }
      if (mounted) _showAndSchedule();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar la calidad: ' + error.toString())),
        );
      }
    }
  }

  String _qualityLabel() {
    if (_qualityId == null) return 'AUTO';
    final track = _firstOrNull(widget.tracks.where((item) => item.id == _qualityId));
    if (track == null) return 'AUTO';
    final height = track.height;
    return height == null ? 'CALIDAD' : height.toString() + 'P';
  }

  String _time(Duration value) {
    final total = value.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? hours.toString() + ':' + mm + ':' + ss
        : mm + ':' + ss;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _surfaceTap,
      onVerticalDragStart: _dragStart,
      onVerticalDragUpdate: _dragUpdate,
      onVerticalDragEnd: _dragEnd,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final duration = value.duration;
          final position = value.position;
          final hasTimeline = duration.inMilliseconds > 0;
          final sliderValue = hasTimeline
              ? position.inMilliseconds.clamp(0, duration.inMilliseconds)
                  .toDouble()
              : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_showControls && !_locked)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    color: Colors.black.withAlpha(150),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.circle,
                          color: _channelPink,
                          size: 7,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (widget.fullscreen)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onExitFullscreen,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_showControls && !_locked)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                    color: Colors.black.withAlpha(175),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (hasTimeline)
                          Row(
                            children: <Widget>[
                              Text(
                                _time(position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: 0,
                                  max: duration.inMilliseconds.toDouble(),
                                  value: sliderValue,
                                  activeColor: _channelCyan,
                                  inactiveColor: _channelMuted.withAlpha(90),
                                  onChangeStart: (_) {
                                    _hideTimer?.cancel();
                                  },
                                  onChanged: (next) {
                                    widget.controller.seekTo(
                                      Duration(milliseconds: next.round()),
                                    );
                                  },
                                  onChangeEnd: (_) => _scheduleHide(),
                                ),
                              ),
                              Text(
                                _time(duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                _locked = true;
                                _showControls = false;
                                _hideTimer?.cancel();
                              }),
                              icon: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'Bloquear controles',
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _togglePlayback,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: _channelCyan,
                                size: 30,
                              ),
                              tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Resolución automática o manual',
                              onSelected: _selectQuality,
                              color: _channelPanel,
                              itemBuilder: (context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'auto',
                                  child: Text(
                                    'Automática',
                                    style: TextStyle(color: _channelCyan),
                                  ),
                                ),
                                for (final track in widget.tracks)
                                  PopupMenuItem<String>(
                                    value: track.id,
                                    child: Text(
                                      track.height == null
                                          ? 'Pista disponible'
                                          : track.height.toString() + 'p',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  _qualityLabel(),
                                  style: const TextStyle(
                                    color: _channelGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: widget.onFullscreen,
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'Pantalla completa',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_locked)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IconButton.filled(
                    onPressed: () {
                      setState(() {
                        _locked = false;
                        _showControls = true;
                      });
                      _scheduleHide();
                    },
                    icon: const Icon(Icons.lock_open_rounded),
                    color: Colors.black,
                    style: IconButton.styleFrom(
                      backgroundColor: _channelCyan,
                    ),
                    tooltip: 'Desbloquear controles',
                  ),
                ),
              if (_gestureLabel != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(200),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _channelCyan.withAlpha(160)),
                    ),
                    child: Text(
                      _gestureLabel!,
                      style: const TextStyle(
                        color: _channelCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelFullscreenScreen extends StatefulWidget {
  const _ChannelFullscreenScreen({
    required this.controller,
    required this.title,
    required this.tracks,
  });

  final VideoPlayerController controller;
  final String title;
  final List<VideoTrack> tracks;

  @override
  State<_ChannelFullscreenScreen> createState() =>
      _ChannelFullscreenScreenState();
}

class _ChannelFullscreenScreenState extends State<_ChannelFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    ));
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[DeviceOrientation.portraitUp],
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.controller.value.aspectRatio > 0
              ? widget.controller.value.aspectRatio
              : 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              VideoPlayer(widget.controller),
              _ChannelPlayerSurface(
                controller: widget.controller,
                title: widget.title,
                tracks: widget.tracks,
                fullscreen: true,
                onFullscreen: () {},
                onExitFullscreen: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChannelAdminScreen extends StatefulWidget {
  const ChannelAdminScreen({super.key});

  @override
  State<ChannelAdminScreen> createState() => _ChannelAdminScreenState();
}

class _ChannelAdminScreenState extends State<ChannelAdminScreen> {
  final ChannelCatalogService _service = channelCatalogService;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _adminScrollController = ScrollController();
  List<SportsChannel> _channels = <SportsChannel>[];
  SportsChannel? _previewChannel;
  List<ChannelPlaylistSource> _sources = <ChannelPlaylistSource>[];
  bool _loading = false;
  bool _working = false;
  bool _rightsConfirmed = false;
  bool _hasMore = true;
  String? _email;
  String? _error;
  String? _sourcesError;

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    _searchController.dispose();
    _adminScrollController.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final email = await _service.signIn();
      if (!mounted) return;
      setState(() => _email = email);
      await _loadAdmin();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _service.signOut();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _email = null;
        _channels = <SportsChannel>[];
        _sources = <ChannelPlaylistSource>[];
        _previewChannel = null;
      });
    }
  }

  Future<void> _loadAdmin({bool showLoading = true}) async {
    if (_email == null && _service.signedInEmail == null) return;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    // El catálogo y las fuentes son servicios independientes. Un fallo al
    // consultar las listas IPTV no debe borrar ni bloquear los canales.
    try {
      final channels = await _service.fetchAdminChannels(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _channels = channels;
        final previewId = _previewChannel?.id;
        if (previewId != null) {
          for (final channel in channels) {
            if (channel.id == previewId) {
              _previewChannel = channel;
              break;
            }
          }
        }
        _hasMore = channels.length == 200;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
      return;
    }

    try {
      var sources = await _service.fetchSources();

      // La primera fuente se registra automáticamente en el servidor cuando
      // el administrador abre este menú por primera vez. No duplica la URL.
      final hasDefaultSource = sources.any(
        (source) => source.url.trim() == _defaultSportsPlaylistUrl,
      );
      if (!hasDefaultSource) {
        await _service.addPlaylist(
          url: _defaultSportsPlaylistUrl,
          label: 'IPTV-org · Deportes (principal)',
        );
        await _service.refreshSources();
        sources = await _service.fetchSources();
      }

      if (!mounted) return;
      sources.sort((a, b) {
        final aDefault = a.url.trim() == _defaultSportsPlaylistUrl;
        final bDefault = b.url.trim() == _defaultSportsPlaylistUrl;
        if (aDefault == bDefault) return 0;
        return aDefault ? -1 : 1;
      });
      setState(() {
        _sources = sources;
        _sourcesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // Conserva el catálogo ya cargado y comunica solo el fallo de fuentes.
        _sourcesError = error.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final more = await _service.fetchAdminChannels(
        search: _searchController.text,
        offset: _channels.length,
      );
      if (!mounted) return;
      setState(() {
        _channels.addAll(more);
        _hasMore = more.length == 200;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _addPlaylist() async {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _message('Introduce una URL HTTPS pública de una lista M3U.');
      return;
    }
    if (!_rightsConfirmed) {
      _message('Confirma que tienes derecho a distribuir esas señales.');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.addPlaylist(
        url: uri.toString(),
        label: _labelController.text.trim(),
      );
      if (!mounted) return;
      _urlController.clear();
      _labelController.clear();
      setState(() => _rightsConfirmed = false);
      _message('Lista añadida. Cloudflare la importará en segundo plano.');
      await _loadAdmin(showLoading: false);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importSuggestedPlaylist(
    _SuggestedSportsPlaylist playlist,
  ) async {
    final alreadyAdded = _sources.any(
      (source) => source.url.trim() == playlist.url,
    );
    if (alreadyAdded) {
      _message('Esta lista ya está registrada.');
      return;
    }

    setState(() => _working = true);
    try {
      await _service.addPlaylist(url: playlist.url, label: playlist.label);
      await _service.refreshSources();
      await _loadAdmin(showLoading: false);
      _message('Lista agregada. El servidor comenzó a importarla.');
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _refreshSources() async {
    setState(() => _working = true);
    try {
      await _service.refreshSources();
      await _loadAdmin(showLoading: false);
      _message('Actualización solicitada al servidor.');
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _previewChannelInAdmin(SportsChannel channel) {
    setState(() => _previewChannel = channel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_adminScrollController.hasClients) return;
      _adminScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _toggleVisibility(SportsChannel channel) async {
    final next = !channel.visible;
    try {
      await _service.setVisibility(channel.id, visible: next);
      await _loadAdmin(showLoading: false);
      _message(next
          ? 'Canal publicado para todos los usuarios.'
          : 'Canal ocultado para todos los usuarios.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _setChannelLanguage(
    SportsChannel channel,
    String language,
  ) async {
    try {
      await _service.setLanguage(channel.id, language: language);
      await _loadAdmin(showLoading: false);
      _message(language == 'es'
          ? 'Idioma guardado: Español 🇪🇸'
          : language == 'en'
              ? 'Idioma guardado: Inglés 🇺🇸'
              : 'Idioma automático/sin definir guardado.');
    } catch (error) {
      _message('No se pudo guardar el idioma: ' + error.toString());
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    _message(label + ' copiado.');
  }

  String _sourceStatus(ChannelPlaylistSource source) {
    switch (source.status) {
      case 'queued':
        return 'EN COLA';
      case 'imported':
        return 'ACTUALIZADA';
      case 'error':
        return 'ERROR: ' + source.lastError;
      default:
        return source.status.toUpperCase();
    }
  }

  Widget _adminCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _channelPanel.withAlpha(245),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _channelLine),
        boxShadow: <BoxShadow>[
          BoxShadow(color: _channelCyan.withAlpha(12), blurRadius: 14),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAdminChannel(SportsChannel channel, int index) {
    final sport = channel.isSports;
    return _adminCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _channelCyan.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (index + 1).toString(),
              style: const TextStyle(
                color: _channelCyan,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 9),
          _ChannelLogo(channel: channel, size: 37),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        channel.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ChannelLanguageBadge(language: channel.language),
                  ],
                ),
                Text(
                  sport ? 'DEPORTIVO' : 'SIN CLASIFICAR',
                  style: TextStyle(
                    color: sport ? _channelGreen : _channelMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'PROBAR CANAL',
                    onPressed: () => _previewChannelInAdmin(channel),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      color: _channelCyan,
                      size: 20,
                    ),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: channel.language,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: _channelPanel2,
                    icon: const Icon(
                      Icons.translate_rounded,
                      color: _channelCyan,
                      size: 15,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'unknown',
                        child: Text('IDIOMA: Sin definir', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem<String>(
                        value: 'es',
                        child: Text('IDIOMA: Español 🇪🇸', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem<String>(
                        value: 'en',
                        child: Text('IDIOMA: Inglés 🇺🇸', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && value != channel.language) {
                        unawaited(_setChannelLanguage(channel, value));
                      }
                    },
                  ),
                ),
                Text(
                  'ID: ' + channel.identifier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _channelMuted,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar identificador',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(channel.identifier, 'Identificador'),
            icon: const Icon(
              Icons.tag_rounded,
              color: _channelCyan,
              size: 19,
            ),
          ),
          IconButton(
            tooltip: 'Copiar URL de señal',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(channel.url, 'URL de señal'),
            icon: const Icon(
              Icons.copy_rounded,
              color: _channelMuted,
              size: 17,
            ),
          ),
          IconButton(
            tooltip: channel.visible ? 'Ocultar a todos' : 'Publicar para todos',
            visualDensity: VisualDensity.compact,
            onPressed: sport ? () => _toggleVisibility(channel) : null,
            icon: Icon(
              channel.visible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: channel.visible ? _channelGreen : _channelMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _email != null || _service.signedInEmail != null;
    return Scaffold(
      backgroundColor: _channelBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF041021),
        title: const Text(
          'ADMINISTRACIÓN · DAMIÁN.APK',
          style: TextStyle(
            color: _channelPink,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        actions: <Widget>[
          if (loggedIn)
            IconButton(
              onPressed: _signOut,
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout_rounded, color: _channelMuted),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: <Color>[
              Color(0xFF10213D),
              _channelBg,
              Color(0xFF02050C),
            ],
            stops: <double>[0, 0.55, 1],
          ),
        ),
        child: !loggedIn
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: _adminCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: _channelPink,
                          size: 52,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'PANEL PRIVADO DE CANALES',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Acceso protegido por Google. Solo la cuenta autorizada en el servidor puede importar listas y publicar canales para todos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _channelMuted,
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _channelPink),
                          ),
                        ],
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _working ? null : _signIn,
                            icon: _working
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: const Text('ENTRAR CON GOOGLE'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _channelCyan,
                              foregroundColor: _channelBg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                color: _channelCyan,
                backgroundColor: _channelPanel,
                onRefresh: () => _loadAdmin(),
                child: ListView(
                  controller: _adminScrollController,
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 26),
                  children: <Widget>[
                    _adminCard(
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.verified_user_rounded,
                            color: _channelGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sesión: ' + (_email ?? _service.signedInEmail ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _adminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'REPRODUCTOR DE PRUEBA',
                                  style: TextStyle(
                                    color: _channelCyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (_previewChannel != null)
                                IconButton(
                                  tooltip: 'Cerrar prueba',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setState(
                                    () => _previewChannel = null,
                                  ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _channelMuted,
                                  ),
                                ),
                            ],
                          ),
                          if (_previewChannel == null)
                            const Text(
                              'Elige un canal del catálogo y pulsa PROBAR CANAL. Podrás comprobar la señal aquí antes de publicarla.',
                              style: TextStyle(
                                color: _channelMuted,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            )
                          else ...<Widget>[
                            Text(
                              _previewChannel!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 7),
                            ChannelInlinePlayer(
                              key: ValueKey<String>(
                                'admin-preview-${_previewChannel!.id}',
                              ),
                              channel: _previewChannel,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _previewChannel!.visible
                                  ? 'Prueba privada. Este canal ya está publicado; la prueba no cambia su estado.'
                                  : 'Prueba privada. El canal seguirá oculto hasta que actives el icono del ojo.',
                              style: const TextStyle(
                                color: _channelMuted,
                                fontSize: 9,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _adminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'FUENTES PÚBLICAS PARA IMPORTAR',
                            style: TextStyle(
                              color: _channelCyan,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'La primera fuente se registra automáticamente. Las demás se agregan cuando las selecciones.',
                            style: TextStyle(
                              color: _channelMuted,
                              fontSize: 10,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final playlist in _suggestedSportsPlaylists)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _channelPanel2,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _channelLine),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.playlist_play_rounded,
                                      color: _channelGreen,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            playlist.label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            playlist.description,
                                            style: const TextStyle(
                                              color: _channelMuted,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Builder(
                                      builder: (context) {
                                        final added = _sources.any(
                                          (source) => source.url.trim() == playlist.url,
                                        );
                                        return OutlinedButton(
                                          onPressed: _working || added
                                              ? null
                                              : () => _importSuggestedPlaylist(playlist),
                                          child: Text(added ? 'AGREGADA' : 'AGREGAR'),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _adminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'AGREGAR LISTA IPTV',
                            style: TextStyle(
                              color: _channelCyan,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _labelController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la lista',
                              hintText: 'Ej. Lista deportiva autorizada',
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'URL HTTPS de la lista M3U',
                              hintText: 'https://servidor/lista.m3u',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 7),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _rightsConfirmed,
                            activeColor: _channelGreen,
                            title: const Text(
                              'Confirmo que puedo distribuir estas señales: son mías, autorizadas o gratuitas con permiso de retransmisión.',
                              style: TextStyle(
                                color: _channelMuted,
                                fontSize: 10,
                                height: 1.35,
                              ),
                            ),
                            onChanged: (value) => setState(
                              () => _rightsConfirmed = value ?? false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _working ? null : _addPlaylist,
                              icon: const Icon(Icons.cloud_download_rounded),
                              label: const Text('IMPORTAR EN CLOUDFLARE'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _channelGreen,
                                foregroundColor: _channelBg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'La lista se procesa en el servidor aunque la APK se cierre. Los canales nuevos entran ocultos y no se publican hasta que actives su ojo.',
                            style: TextStyle(
                              color: _channelMuted,
                              fontSize: 9,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'LISTAS REGISTRADAS',
                            style: TextStyle(
                              color: _channelPink,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _working ? null : _refreshSources,
                          icon: const Icon(
                            Icons.sync_rounded,
                            color: _channelCyan,
                          ),
                          tooltip: 'Actualizar listas',
                        ),
                      ],
                    ),
                    if (_sourcesError != null)
                      _adminCard(
                        child: Text(
                          'No se pudieron consultar las listas registradas: ' +
                              _sourcesError!,
                          style: const TextStyle(
                            color: _channelYellow,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (_sources.isEmpty)
                      _adminCard(
                        child: const Text(
                          'Todavía no hay listas registradas.',
                          style: TextStyle(color: _channelMuted),
                        ),
                      )
                    else
                      for (final source in _sources)
                        _adminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                source.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                Uri.tryParse(source.url)?.host ?? 'Fuente M3U',
                                style: const TextStyle(
                                  color: _channelMuted,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _sourceStatus(source),
                                style: TextStyle(
                                  color: source.status == 'error'
                                      ? _channelPink
                                      : _channelGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                source.importedCount.toString() +
                                    ' canales procesados',
                                style: const TextStyle(
                                  color: _channelMuted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'CATÁLOGO GENERAL',
                            style: TextStyle(
                              color: _channelCyan,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          _channels.length.toString() + ' cargados',
                          style: const TextStyle(
                            color: _channelMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _loadAdmin(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar canal por nombre...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _channelCyan,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _loadAdmin,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: _channelGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: _channelPink,
                          fontSize: 11,
                        ),
                      ),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: _channelCyan,
                          ),
                        ),
                      ),
                    for (var i = 0; i < _channels.length; i++)
                      _buildAdminChannel(_channels[i], i),
                    if (_hasMore)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _loadMore,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('CARGAR MÁS CANALES'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
