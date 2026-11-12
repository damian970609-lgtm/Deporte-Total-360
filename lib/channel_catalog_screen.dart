import 'app_section_design.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import 'channel_catalog_service.dart';
import 'channel_local_iptv_store.dart';
import 'channel_proxy_service.dart';
import 'channel_playlist_presets.dart';
import 'live_media_format.dart';
import 'stream_diagnostics.dart';

const Color _channelBg = Color(0xFF000000);
const Color _channelPanel = Color(0xFF07090D);
const Color _channelPanel2 = Color(0xFF0D1118);
const Color _channelLine = Color(0xFF0047FF);
const Color _channelCyan = Color(0xFF00A3FF);
const Color _channelPink = Color(0xFFFF1744);
const Color _channelGreen = Color(0xFF39FF14);
const Color _channelYellow = Color(0xFFFFFFFF);
const Color _channelMuted = Color(0xFFEAF0F8);
const String _channelFavoritesKey = 'dt360_channel_catalog_favorites_v1';
const String _channelCatalogCacheKey = channelCatalogSnapshotCacheKey;
const int _maxCachedChannels = maxCachedChannelCatalogEntries;


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
  List<SportsChannel> _cachedChannels = <SportsChannel>[];
  SportsChannel? _selectedChannel;
  Timer? _searchDebounce;
  int _catalogRequestId = 0;
  int _nextCatalogOffset = 0;
  int _catalogTotal = 0;
  bool _catalogTotalIsEstimate = false;
  bool _hasMoreChannels = false;
  bool _loadingMoreChannels = false;
  String? _loadMoreError;
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  String? _catalogNotice;
  String? _signedInEmail;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleCatalogScroll);
    unawaited(_loadLocalFavorites());
    unawaited(_initializeCatalog());
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

  Future<void> _initializeCatalog() async {
    await _loadCachedCatalog();
    if (mounted) await _loadChannels();
  }

  Future<void> _loadCachedCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_channelCatalogCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final cached = <SportsChannel>[];
      for (final row in decoded.whereType<Map>()) {
        try {
          cached.add(SportsChannel.fromJson(Map<String, dynamic>.from(row)));
        } on FormatException {
          // Descarta una entrada dañada sin perder los demás canales.
        }
      }
      if (!mounted || cached.isEmpty) return;
      setState(() {
        _cachedChannels = cached.take(_maxCachedChannels).toList();
        _channels = List<SportsChannel>.from(_cachedChannels);
        _catalogTotal = _cachedChannels.length;
        _catalogTotalIsEstimate = false;
        _nextCatalogOffset = _cachedChannels.length;
        _hasMoreChannels = false;
        _catalogNotice =
            'Mostrando la última copia guardada mientras se actualiza el catálogo.';
      });
    } catch (_) {
      // La copia local nunca debe impedir intentar la conexión actual.
    }
  }

  Future<void> _saveLocalCatalog() async {
    if (_cachedChannels.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = _cachedChannels.take(_maxCachedChannels).toList();
      await prefs.setString(
        _channelCatalogCacheKey,
        jsonEncode(snapshot.map((channel) => channel.toJson()).toList()),
      );
    } catch (_) {
      // El catálogo remoto sigue funcionando aunque falle el almacenamiento local.
    }
  }

  Future<void> _loadChannels() async {
    _searchDebounce?.cancel();
    final requestId = ++_catalogRequestId;
    final search = _searchController.text.trim();
    final fallback = _cachedChannels.isNotEmpty
        ? List<SportsChannel>.from(_cachedChannels)
        : List<SportsChannel>.from(_channels);
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMoreChannels = false;
        _loadMoreError = null;
        _error = null;
        _catalogNotice = fallback.isEmpty
            ? null
            : 'Conservando la última copia del catálogo durante la actualización.';
        // No vaciar la lista antes de consultar Cloudflare: si se agota la
        // cuota, los canales guardados deben seguir visibles en este teléfono.
        _channels = fallback;
        _catalogTotal = fallback.length;
        _catalogTotalIsEstimate = false;
        _nextCatalogOffset = fallback.length;
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
        _catalogTotalIsEstimate = page.totalIsEstimate;
        _nextCatalogOffset = page.offset + page.channels.length;
        _hasMoreChannels = page.hasMore;
        _selectedChannel = _firstOrNull(
          page.channels.where((item) => item.id == previousId),
        );
        _loading = false;
        _catalogNotice = null;
        if (search.isEmpty) {
          final cachedById = <String, SportsChannel>{
            for (final channel in _cachedChannels) channel.id: channel,
          };
          for (final channel in page.channels) {
            cachedById[channel.id] = channel;
          }
          _cachedChannels = cachedById.values
              .take(_maxCachedChannels)
              .toList();
        }
      });
      if (search.isEmpty) unawaited(_saveLocalCatalog());
    } catch (error) {
      if (!mounted || requestId != _catalogRequestId) return;
      final hasFallback = _cachedChannels.isNotEmpty || fallback.isNotEmpty;
      setState(() {
        _loading = false;
        if (hasFallback) {
          _channels = _cachedChannels.isNotEmpty
              ? List<SportsChannel>.from(_cachedChannels)
              : fallback;
          _catalogTotal = _channels.length;
          _catalogTotalIsEstimate = false;
          _nextCatalogOffset = _channels.length;
          _hasMoreChannels = false;
          _error = null;
          _catalogNotice =
              'Cloudflare no está disponible o alcanzó su cuota diaria. Se conserva tu catálogo guardado y tus favoritos en este teléfono.';
          if (_selectedChannel == null ||
              !_channels.any((channel) => channel.id == _selectedChannel!.id)) {
            _selectedChannel = _firstOrNull(_channels);
          }
        } else {
          _error = error.toString();
        }
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
        final additions = page.channels
            .where((channel) => knownIds.add(channel.id))
            .toList(growable: false);
        _channels = <SportsChannel>[..._channels, ...additions];
        if (search.isEmpty) {
          final cachedIds = _cachedChannels.map((channel) => channel.id).toSet();
          _cachedChannels = <SportsChannel>[
            ..._cachedChannels,
            ...additions.where((channel) => cachedIds.add(channel.id)),
          ].take(_maxCachedChannels).toList();
        }
        _catalogTotal = page.total;
        _catalogTotalIsEstimate = page.totalIsEstimate;
        _nextCatalogOffset = page.offset + page.channels.length;
        _hasMoreChannels = page.hasMore;
      });
      if (search.isEmpty) unawaited(_saveLocalCatalog());
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
      final combined = <String>{..._favorites, ...remote};
      if (combined.length != remote.length) {
        await _service.saveFavorites(combined);
      }
      _favorites
        ..clear()
        ..addAll(combined);
      await _saveLocalFavorites();
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
    return ColoredBox(color: _channelBg, child: child);
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
        backgroundColor: const Color(0xFF07090D),
        title: const AppSectionTitle(
          icon: Icons.grid_view_rounded,
          title: 'CANALES DEPORTIVOS',
          accent: _channelCyan,
          subtitle: 'CATÁLOGO Y REPRODUCTOR',
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
                              _catalogTotalIsEstimate
                                   ? channels.length.toString() + '+ canales'
                                   : _catalogTotal.toString() + ' canales',
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
                      if (_catalogNotice != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.cloud_off_rounded,
                              color: _channelYellow,
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _catalogNotice!,
                                style: const TextStyle(
                                  color: _channelYellow,
                                  fontSize: 9,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_loading && channels.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _channelCyan),
                  ),
                )
              else if (_error != null && channels.isEmpty)
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
                        label: const Text('CARGAR SIGUIENTES CANALES · DESLIZA PARA SEGUIR'),
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
    this.showProxyControls = true,
  });

  final SportsChannel? channel;
  final bool showProxyControls;

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
    unawaited(_clearNativeProxySafely());
    super.dispose();
  }

  Future<void> _clearNativeProxySafely() async {
    try {
      await ChannelProxyPlatform.clear();
    } catch (_) {}
  }

  void _handleVideoChanged() {
    final controller = _controller;
    if (controller != null && controller.value.hasError &&
        _activeProxyIndex >= 0 && !_retryingProxy) {
      if (_activeProxyIndex + 1 < _proxies.length) {
        _retryingProxy = true;
        unawaited(_initialize(startAt: _activeProxyIndex + 1));
        return;
      }
      final error = controller.value.errorDescription;
      _controller = null;
      unawaited(controller.dispose());
      unawaited(_clearNativeProxySafely());
      _activeProxyIndex = -1;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'El proxy activo dejó de funcionar y no quedan proxies de reserva. ' +
              (error ?? '');
        });
      }
      return;
    }
    if (mounted) setState(() {});
  }

  final ChannelProxyStore _proxyStore = ChannelProxyStore();
  List<ChannelProxyEndpoint> _proxies = <ChannelProxyEndpoint>[];
  int _activeProxyIndex = -1;
  bool _retryingProxy = false;

  Future<void> _initialize({int startAt = 0}) async {
    final previous = _controller;
    _controller = null;
    previous?.removeListener(_handleVideoChanged);
    await previous?.dispose();
    try {
      await ChannelProxyPlatform.clear();
    } catch (_) {}
    if (!mounted) return;

    final channel = widget.channel;
    if (channel == null) {
      setState(() {
        _loading = false;
        _error = null;
        _tracks = <VideoTrack>[];
        _proxies = <ChannelProxyEndpoint>[];
        _activeProxyIndex = -1;
      });
      return;
    }

    if (!isSupportedChannelPlaybackUrl(channel.url)) {
      setState(() {
        _loading = false;
        _error = 'La fuente no es una señal HTTPS directa compatible (HLS, DASH, Smooth Streaming o vídeo progresivo).';
      });
      return;
    }
    if (startAt == 0) {
      _proxies = await _proxyStore.loadForChannel(channel.id);
    }
    if (!mounted) return;
    final uri = Uri.parse(channel.url.trim());

    setState(() {
      _loading = true;
      _error = null;
      _tracks = <VideoTrack>[];
    });

    final attempts = _proxies.isEmpty ? 1 : _proxies.length;
    Object? lastError;
    for (var index = startAt; index < attempts; index++) {
      VideoPlayerController? controller;
      try {
        if (_proxies.isEmpty) {
          await ChannelProxyPlatform.clear();
        } else {
          await ChannelProxyPlatform.apply(_proxies[index], channel.url);
        }
        controller = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _controller = controller;
        await controller.initialize().timeout(const Duration(seconds: 18));
        await controller.setLooping(false);
        await controller.setVolume(1);
        var tracks = <VideoTrack>[];
        if (controller.isVideoTrackSupportAvailable()) {
          try {
            await controller.selectVideoTrack(null);
            tracks = (await controller.getVideoTracks()).toList()
              ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
          } catch (_) {
            tracks = <VideoTrack>[];
          }
        }
        if (!mounted || !identical(_controller, controller)) {
          await controller.dispose();
          return;
        }
        _tracks = tracks;
        _activeProxyIndex = _proxies.isEmpty ? -1 : index;
        if (index > 0 && index < _proxies.length) {
          // Recuerda el último proxy que logró iniciar este canal para que
          // sea la primera opción en la siguiente reproducción.
          unawaited(_rememberWorkingProxy(channel.id, _proxies[index].id));
        }
        controller.addListener(_handleVideoChanged);
        setState(() {
          _loading = false;
          _error = null;
          _retryingProxy = false;
        });
        await controller.play();
        if (mounted) setState(() {});
        return;
      } catch (error) {
        lastError = error;
        if (controller != null) {
          controller.removeListener(_handleVideoChanged);
          try {
            await controller.dispose();
          } catch (_) {}
          if (identical(_controller, controller)) _controller = null;
        }
        if (!mounted) return;
        if (_proxies.isNotEmpty && index + 1 < _proxies.length) {
          setState(() {
            _loading = true;
            _error = 'El proxy ${index + 1} no respondió. Probando automáticamente el siguiente (${index + 2}/${_proxies.length})…';
          });
        }
      }
    }

    try {
      await ChannelProxyPlatform.clear();
    } catch (_) {}
    _activeProxyIndex = -1;
    _retryingProxy = false;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = _proxies.isEmpty
          ? explainVideoPlayerError(lastError ?? 'No se pudo iniciar el reproductor.')
          : 'No funcionó ninguno de los ${_proxies.length} proxies de este canal. Revisa las direcciones o prueba otros.';
    });
  }

  Future<void> _rememberWorkingProxy(
    String channelId,
    String proxyId,
  ) async {
    try {
      await _proxyStore.moveToFront(channelId, proxyId);
    } catch (_) {
      // Un fallo al guardar la preferencia no debe interrumpir el vídeo.
    }
  }

  Future<void> _configureChannelProxies() async {
    final channel = widget.channel;
    if (channel == null) return;
    final proxies = List<ChannelProxyEndpoint>.from(
      await _proxyStore.loadForChannel(channel.id),
    );
    final input = TextEditingController();
    String? validationError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _channelPanel,
          title: Text(
            'PROXIES · ${channel.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _channelCyan,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Añade hasta 10 proxies. El reproductor los probará en orden y cambiará al siguiente si falla la conexión. Solo se aplican a este canal.',
                  style: TextStyle(color: _channelMuted, fontSize: 10),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: input,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: const InputDecoration(
                    labelText: 'Dirección del proxy',
                    hintText: 'host:puerto, http://usuario:clave@host:puerto o socks5://host:puerto',
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: proxies.length >= maxChannelProxiesPerChannel
                        ? null
                        : () {
                            try {
                              final proxy = ChannelProxyEndpoint.parse(input.text);
                              if (proxies.any((item) => item.id == proxy.id)) {
                                throw const FormatException('Ese proxy ya está en la lista.');
                              }
                              setDialogState(() {
                                proxies.add(proxy);
                                input.clear();
                                validationError = null;
                              });
                            } catch (error) {
                              setDialogState(() => validationError = error.toString());
                            }
                          },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('AÑADIR ${proxies.length}/10'),
                  ),
                ),
                if (validationError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      validationError!,
                      style: const TextStyle(color: _channelPink, fontSize: 9),
                    ),
                  ),
                const Divider(color: _channelLine),
                SizedBox(
                  height: 210,
                  child: proxies.isEmpty
                      ? const Center(
                          child: Text(
                            'Este canal funciona sin proxy.',
                            style: TextStyle(color: _channelMuted, fontSize: 11),
                          ),
                        )
                      : ListView.builder(
                          itemCount: proxies.length,
                          itemBuilder: (context, index) {
                            final proxy = proxies[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: _channelCyan.withAlpha(25),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: _channelCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              title: Text(
                                proxy.displayAddress,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                              subtitle: Text(
                                proxy.username.isEmpty ? 'Sin autenticación' : 'Con autenticación',
                                style: const TextStyle(color: _channelMuted, fontSize: 8),
                              ),
                              trailing: IconButton(
                                tooltip: 'Eliminar proxy',
                                onPressed: () => setDialogState(
                                  () => proxies.removeAt(index),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: _channelPink,
                                  size: 19,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (saved != true) return;
    await _proxyStore.saveForChannel(channel.id, proxies);
    if (!mounted) return;
    _proxies = List<ChannelProxyEndpoint>.from(proxies);
    setState(() {});
    await _initialize();
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
                  if (_error != null)
                    StreamDiagnosticButton(
                      url: widget.channel!.url,
                      compact: true,
                      color: _channelCyan,
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
          if (widget.showProxyControls)
            Positioned(
            left: 7,
            top: 7,
            child: Material(
              color: Colors.black.withAlpha(205),
              borderRadius: BorderRadius.circular(9),
              child: TextButton.icon(
                key: ValueKey<String>('channel-proxy-config-${widget.channel?.id ?? 'none'}'),
                onPressed: widget.channel == null ? null : _configureChannelProxies,
                icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                label: Text('PROXY ${_proxies.length}/10'),
                style: TextButton.styleFrom(
                  foregroundColor: _channelCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                ),
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
  const ChannelAdminScreen({
    super.key,
    this.service,
    this.snapshotLoader,
    this.localStore,
  });

  final ChannelCatalogService? service;
  final Future<ChannelAdminSnapshot?> Function(String email)? snapshotLoader;
  final ChannelLocalIptvStore? localStore;

  @override
  State<ChannelAdminScreen> createState() => _ChannelAdminScreenState();
}

class _ChannelAdminScreenState extends State<ChannelAdminScreen> {
  late final ChannelCatalogService _service;
  late final ChannelLocalIptvStore _iptvStore;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _licenseEmailController = TextEditingController();
  final TextEditingController _licenseNoteController = TextEditingController();
  final ScrollController _adminScrollController = ScrollController();
  String _licenseType = 'free';
  String _selectedSportsPresetUrl = channelSportsPlaylistPresets.first.url;
  String _selectedGeneralPresetUrl = channelPlaylistPresets.first.url;
  List<AppLicenseRecord> _licenseRecords = <AppLicenseRecord>[];
  String? _licensesError;
  Map<String, dynamic> _trialSummary = <String, dynamic>{};
  List<String> _newTrialCodes = <String>[];
  String? _trialError;
  // El panel nunca debe construir miles de tarjetas a partir de la copia local.
  // Se muestra un bloque y el resto del snapshot se pagina bajo demanda.
  static const int _adminPageSize = 40;
  List<SportsChannel> _channels = <SportsChannel>[];
  List<SportsChannel> _cachedAdminChannels = <SportsChannel>[];
  SportsChannel? _previewChannel;
  List<ChannelPlaylistSource> _sources = <ChannelPlaylistSource>[];
  static const int _sourcePageSize = 15;
  int _visibleSourceCount = _sourcePageSize;
  bool _loading = false;
  bool _working = false;
  bool _automaticCatalogCompletionAttempted = false;
  bool _rightsConfirmed = false;
  bool _hasMore = true;
  int _catalogTotal = 0;
  bool _catalogTotalIsEstimate = false;
  int _nextAdminOffset = 0;
  bool _diagnosingPreview = false;
  String? _diagnosticResult;
  String? _email;
  String? _error;
  String? _sourcesError;
  bool _showIptvSection = false;
  bool _iptvLoading = false;
  bool _iptvLoaded = false;
  bool _iptvCacheComplete = false;
  int _iptvNextOffset = 0;
  int _iptvRequestId = 0;
  List<SportsChannel> _iptvChannels = <SportsChannel>[];
  SportsChannel? _iptvSelectedChannel;
  String? _iptvError;
  final TextEditingController _iptvSearchController = TextEditingController();
  final GlobalKey<_ChannelInlinePlayerState> _iptvPlayerKey =
      GlobalKey<_ChannelInlinePlayerState>();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? channelCatalogService;
    _iptvStore = widget.localStore ?? ChannelLocalIptvStore();
    _adminScrollController.addListener(_handleAdminScroll);
    _working = true;
    unawaited(_restoreAdminSession());
  }

  /// Al abrir el menú intenta recuperar la cuenta previa de Google.
  /// Si el SDK no puede hacerlo sin interacción, deja disponible el botón
  /// de acceso manual y conserva intactas las listas del servidor.
  Future<void> _restoreAdminSession() async {
    try {
      final email = await _service.restoreSession();
      if (!mounted || email == null) return;
      setState(() => _email = email);

      // La copia local se muestra primero. El panel deja de bloquear sus
      // controles mientras las consultas remotas se ejecutan en paralelo.
      await _loadCachedAdminSnapshot(email);
      if (!mounted) return;
      setState(() => _working = false);
      unawaited(_loadAdmin());
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Google tardó demasiado en restaurar la sesión. Puedes entrar manualmente.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _handleAdminScroll() {
    if (_showIptvSection || !_adminScrollController.hasClients ||
        _loading || _working || !_hasMore || _error != null) {
      return;
    }
    if (_adminScrollController.position.extentAfter < 650) {
      unawaited(_loadMore());
    }
  }

  @override
  void dispose() {
    _adminScrollController.removeListener(_handleAdminScroll);
    _urlController.dispose();
    _labelController.dispose();
    _searchController.dispose();
    _licenseEmailController.dispose();
    _licenseNoteController.dispose();
    _iptvSearchController.dispose();
    _adminScrollController.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _loadCachedAdminSnapshot(String email) async {
    try {
      final snapshot = widget.snapshotLoader == null
          ? await ChannelAdminSnapshotStore.load(email: email)
          : await widget.snapshotLoader!(email);
      if (!mounted || snapshot == null) return;

      setState(() {
        if (snapshot.hasChannels) {
          _cachedAdminChannels = List<SportsChannel>.unmodifiable(
            snapshot.channels.take(maxCachedChannelCatalogEntries),
          );
          _channels = _cachedAdminChannels
              .take(_adminPageSize)
              .toList(growable: true);
          _catalogTotal = _cachedAdminChannels.length;
          // Un snapshot puede contener solo los bloques ya descargados, o
          // estar limitado a 2.000 filas; nunca se presenta como total final.
          _catalogTotalIsEstimate =
              _cachedAdminChannels.length >= _adminPageSize;
          _nextAdminOffset = _channels.length;
          _hasMore = _catalogTotalIsEstimate;
        }
        if (snapshot.hasSources) _sources = snapshot.sources;
        if (snapshot.hasChannels && snapshot.channels.isNotEmpty) {
          _error =
              'Copia local del catálogo. Se actualizará cuando Cloudflare responda.';
        }
        if (snapshot.hasSources) {
          _sourcesError =
              'Listas conservadas en este teléfono. El modo sin conexión es de solo lectura.';
        }
      });
    } catch (_) {
      // Una copia local dañada nunca debe impedir abrir el panel.
    }
  }

  Future<void> _saveLocalAdminSnapshot({
    bool saveChannels = true,
    bool saveSources = true,
  }) async {
    final email = (_email ?? _service.signedInEmail ?? '').trim();
    if (email.isEmpty || (!saveChannels && !saveSources)) return;

    await ChannelAdminSnapshotStore.save(
      email: email,
      channels: saveChannels ? List<SportsChannel>.from(_channels) : null,
      sources: saveSources
          ? List<ChannelPlaylistSource>.from(_sources)
          : null,
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
      await _loadCachedAdminSnapshot(email);
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
    ++_iptvRequestId;
    try {
      await _service.signOut();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _email = null;
        _channels = <SportsChannel>[];
        _sources = <ChannelPlaylistSource>[];
        _automaticCatalogCompletionAttempted = false;
        _licenseRecords = <AppLicenseRecord>[];
        _previewChannel = null;
        _showIptvSection = false;
        _iptvChannels = <SportsChannel>[];
        _iptvSelectedChannel = null;
        _iptvLoaded = false;
        _iptvError = null;
          _catalogTotal = 0;
          _catalogTotalIsEstimate = false;
          _nextAdminOffset = 0;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadAdmin({bool showLoading = true}) async {
    if (_email == null && _service.signedInEmail == null) return;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _sourcesError = null;
      });
    }

    final email = (_email ?? _service.signedInEmail ?? '').trim();
    var hasCompleteLocalCache = false;
    if (email.isNotEmpty) {
      try {
        final cached = await _iptvStore.load(email: email);
        if (!mounted) return;
        if (cached != null) {
          hasCompleteLocalCache = cached.complete;
          setState(() {
            _iptvChannels = List<SportsChannel>.from(cached.channels);
            _sources = cached.sources.isNotEmpty
                ? List<ChannelPlaylistSource>.from(cached.sources)
                : _sources;
            _iptvCacheComplete = cached.complete;
            _iptvNextOffset = cached.nextOffset;
            _iptvLoaded = cached.complete;
          });
        }
      } catch (_) {
        // Si el archivo local está dañado, se recupera el catálogo desde el servidor.
      }
    }

    // Una copia marcada como completa es autosuficiente: abrir el menú otra
    // vez no vuelve a descargar fuentes ni páginas del catálogo.
    if (hasCompleteLocalCache) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    await _loadAdminSources();
    if (!mounted) return;

    if (!_automaticCatalogCompletionAttempted &&
        _sourcesError == null &&
        _sources.length >= 99 &&
        _sources.length < maxChannelPlaylistSources) {
      _automaticCatalogCompletionAttempted = true;
      await _fillPlaylistCatalogTo120(automatic: true);
    }

    if (!mounted) return;
    final importsReady = await _waitForPlaylistImports();
    if (!mounted) return;
    if (!importsReady) {
      final failed = _sources.where((source) => source.status == 'error').length;
      final pending = _sources.where(
        (source) => source.status == 'queued' || source.status == 'importing',
      ).length;
      setState(() {
        _iptvError = failed > 0
            ? '$failed listas no pudieron importarse. El catálogo no se marcará como completo.'
            : '$pending listas siguen importándose. La descarga continuará al volver a abrir este menú.';
        _loading = false;
      });
      return;
    }
    await _loadAllIptvChannels();
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _waitForPlaylistImports() async {
    if (_sources.isEmpty) return false;

    for (var attempt = 0; attempt < 6; attempt++) {
      final pending = _sources.any(
        (source) => source.status == 'queued' || source.status == 'importing',
      );
      if (!pending) {
        return _sources.every((source) => source.status == 'imported');
      }
      if (attempt == 5) break;

      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        final latest = await _service.fetchSources();
        if (!mounted) return false;
        latest.sort((a, b) {
          if (a.status == 'error' && b.status != 'error') return -1;
          if (b.status == 'error' && a.status != 'error') return 1;
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
        setState(() => _sources = latest);
        await _persistIptvSources();
      } catch (_) {
        return false;
      }
    }
    return _sources.isNotEmpty &&
        _sources.every((source) => source.status == 'imported');
  }

  Future<void> _loadAdminChannels() async {
    try {
      final page = await _service.fetchAdminChannelPage(
        search: _searchController.text,
        offset: 0,
        // El inventario se pagina; no materializar miles de tarjetas al abrir.
        limit: _adminPageSize,
      );
      if (!mounted) return;
      setState(() {
        _cachedAdminChannels = <SportsChannel>[];
        _channels = page.channels;
        _catalogTotal = page.total;
        _catalogTotalIsEstimate = page.totalIsEstimate;
        _nextAdminOffset = page.offset + page.channels.length;
        final previewId = _previewChannel?.id;
        if (previewId != null) {
          for (final channel in page.channels) {
            if (channel.id == previewId) {
              _previewChannel = channel;
              break;
            }
          }
        }
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
      await _saveLocalAdminSnapshot(saveChannels: true, saveSources: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _channels.isNotEmpty
            ? 'Cloudflare no está disponible o alcanzó su cuota. Se conserva el catálogo guardado en este teléfono.'
            : error.toString();
      });
    }
  }

  Future<void> _loadAdminSources() async {
    try {
      final sources = await _service.fetchSources();
      if (!mounted) return;
      sources.sort((a, b) {
        if (a.status == 'error' && b.status != 'error') return -1;
        if (b.status == 'error' && a.status != 'error') return 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
      setState(() {
        _sources = sources;
        _visibleSourceCount = _visibleSourceCount.clamp(0, sources.length).toInt();
        _sourcesError = null;
      });
      await _saveLocalAdminSnapshot(saveChannels: false, saveSources: true);
      await _persistIptvSources();
    } catch (error) {
      if (!mounted) return;
      final email = (_email ?? _service.signedInEmail ?? '').trim();
      if (email.isNotEmpty) {
        try {
          final cached = await _iptvStore.load(email: email);
          if (cached != null && cached.sources.isNotEmpty) {
            setState(() => _sources = List<ChannelPlaylistSource>.from(cached.sources));
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _sourcesError = _sources.isNotEmpty
            ? 'Sin conexión. Se muestran las 120 listas conservadas en este teléfono.'
            : error.toString();
      });
    }
  }

  Future<void> _persistIptvSources() async {
    final email = (_email ?? _service.signedInEmail ?? '').trim();
    if (email.isEmpty) return;
    final cached = await _iptvStore.load(email: email);
    await _iptvStore.save(
      email: email,
      channels: cached?.channels ?? _iptvChannels,
      sources: _sources,
      complete: cached?.complete ?? _iptvCacheComplete,
      nextOffset: cached?.nextOffset ?? _iptvNextOffset,
    );
  }

  void _showMoreSources() {
    if (!mounted || _visibleSourceCount >= _sources.length) return;
    setState(() {
      _visibleSourceCount = (_visibleSourceCount + _sourcePageSize)
          .clamp(0, _sources.length)
          .toInt();
    });
  }

  Future<void> _loadLicenses() async {
    try {
      final licenses = await _service.fetchAdminLicenses();
      if (!mounted) return;
      setState(() {
        _licenseRecords = licenses;
        _licensesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _licensesError = error.toString());
    }
  }

  Future<void> _loadTrialSummary() async {
    try {
      final summary = await _service.fetchTrialPassSummary();
      if (!mounted) return;
      setState(() {
        _trialSummary = summary;
        _trialError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _trialError = error.toString());
    }
  }

  Future<void> _generateTrialCodes() async {
    if (_working) return;
    setState(() {
      _working = true;
      _trialError = null;
      _newTrialCodes = <String>[];
    });
    try {
      final codes = await _service.generateTrialPassCodes(count: 10);
      await _loadTrialSummary();
      if (!mounted) return;
      setState(() => _newTrialCodes = codes);
      _message(codes.isEmpty
          ? 'Ya están ocupadas las diez plazas VIP. Libera una plaza antes de generar más.'
          : 'Se generaron ${codes.length} códigos VIP de un solo uso.');
    } catch (error) {
      if (mounted) setState(() => _trialError = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _copyTrialCodes() async {
    if (_newTrialCodes.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: _newTrialCodes.join('\n')),
    );
    _message('Códigos VIP copiados. Guárdalos ahora: no se volverán a mostrar.');
  }

  Future<void> _grantLicense() async {
    final email = _licenseEmailController.text.trim().toLowerCase();
    if (!email.contains('@') || !email.contains('.')) {
      _message('Introduce el correo Google de la persona.');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.grantAppLicense(
        email: email,
        licenseType: _licenseType,
        note: _licenseNoteController.text,
      );
      _licenseEmailController.clear();
      _licenseNoteController.clear();
      await _loadLicenses();
      _message(_licenseType == 'free'
          ? 'Pase gratuito concedido a $email.'
          : 'Licencia de pago activada para $email.');
    } catch (error) {
      _message('No se pudo guardar la licencia: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _revokeLicense(AppLicenseRecord license) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _channelPanel,
        title: const Text('Revocar acceso', style: TextStyle(color: _channelPink)),
        content: Text(
          '¿Quieres retirar la licencia de ${license.email}?',
          style: const TextStyle(color: _channelMuted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _channelPink),
            child: const Text('REVOCAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await _service.revokeAppLicense(email: license.email);
      await _loadLicenses();
      _message('Acceso revocado para ${license.email}.');
    } catch (error) {
      _message('No se pudo revocar la licencia: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _searchChannels() async {
    if (_loading) return;
    await _loadAdmin();
    if (!mounted) return;
    if (_error == null) {
      _message(_channels.isEmpty
          ? 'No se encontraron canales con ese nombre.'
          : 'Canales encontrados: ' + _channels.length.toString());
    }
  }

  Future<void> _clearChannelSearch() async {
    _searchController.clear();
    await _loadAdmin();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;

    // Primero permite recorrer el snapshot local en bloques de 40. Así una
    // cuenta con 2.000 canales guardados no crea 2.000 widgets al abrir.
    if (_channels.length < _cachedAdminChannels.length) {
      final next = _cachedAdminChannels
          .skip(_channels.length)
          .take(_adminPageSize)
          .toList(growable: false);
      setState(() {
        _channels = <SportsChannel>[..._channels, ...next];
        _nextAdminOffset = _channels.length;
        _catalogTotal = _cachedAdminChannels.length;
        _catalogTotalIsEstimate = true;
        // Puede haber más registros en el servidor que los guardados en caché.
        _hasMore = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.fetchAdminChannelPage(
        search: _searchController.text,
        offset: _nextAdminOffset,
        limit: 40,
      );
      if (page.channels.isEmpty && page.hasMore) {
        throw const ChannelCatalogException(
          'El servidor no entregó la siguiente página del catálogo. Vuelve a intentarlo.',
        );
      }
      if (!mounted) return;
      setState(() {
        final knownIds = _channels.map((channel) => channel.id).toSet();
        _channels.addAll(
          page.channels.where((channel) => knownIds.add(channel.id)),
        );
        _cachedAdminChannels = <SportsChannel>[];
        _catalogTotal = page.total;
        _catalogTotalIsEstimate = page.totalIsEstimate;
        _nextAdminOffset = page.offset + page.channels.length;
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
      await _saveLocalAdminSnapshot(saveChannels: true, saveSources: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _channels.isNotEmpty
            ? 'Cloudflare no está disponible. Se mantiene la última copia del catálogo.'
            : error.toString();
      });
    }
  }

  Future<void> _addPlaylist() async {
    if (_sources.length >= maxChannelPlaylistSources) {
      _message('Ya tienes ' + maxChannelPlaylistSources.toString() + ' listas registradas. No se pueden agregar más.');
      return;
    }
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _message('Introduce una URL HTTPS pública de una lista IPTV compatible.');
      return;
    }
    final normalizedUrl = uri.toString();
    if (containsChannelPlaylistUrl(
      _sources.map((source) => source.url),
      normalizedUrl,
    )) {
      _message('Esta lista ya está guardada en tu catálogo.');
      return;
    }
    if (!_rightsConfirmed) {
      _message('Confirma que tienes derecho a distribuir esas señales.');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.addPlaylist(
        url: normalizedUrl,
        label: _labelController.text.trim(),
      );
      if (!mounted) return;
      _urlController.clear();
      _labelController.clear();
      setState(() => _rightsConfirmed = false);
      _message('Lista guardada en Cloudflare. La importación continuará en segundo plano aunque cierres la APK.');
      await _loadAdmin(showLoading: false);
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _addSportsPreset() async {
    if (_sources.length >= maxChannelPlaylistSources) {
      _message('Has alcanzado el límite de $maxChannelPlaylistSources listas.');
      return;
    }
    final preset = channelSportsPlaylistPresets.firstWhere(
      (item) => item.url == _selectedSportsPresetUrl,
      orElse: () => channelSportsPlaylistPresets.first,
    );
    if (containsChannelPlaylistUrl(
      _sources.map((source) => source.url),
      preset.url,
    )) {
      _message('Esta fuente deportiva ya está registrada.');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.addPlaylist(url: preset.url, label: preset.label);
      final sources = await _service.fetchSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _sourcesError = null;
      });
      await _saveLocalAdminSnapshot(saveChannels: false, saveSources: true);
      _message('Fuente añadida: ' + preset.label + '. Se está importando.');
    } catch (error) {
      _message('No se pudo añadir la fuente deportiva: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _fillPlaylistCatalogTo120({bool automatic = false}) async {
    if (_working && !automatic) return;
    if (_sources.length >= maxChannelPlaylistSources) {
      if (!automatic) _message('El catálogo ya tiene 120 listas registradas.');
      return;
    }
    if (!automatic) setState(() => _working = true);
    try {
      // Envía las 120 fuentes para que el Worker compare el catálogo
      // completo con las listas guardadas y añada solo las que falten.
      // Así se completan las 120 aunque la fuente número 100 ya exista.
      final result = await _service.addPlaylistSourcesToCatalog(
        sources: channelPlaylistPresets
            .map((preset) => <String, String>{
                  'label': preset.label,
                  'url': preset.url,
                })
            .toList(growable: false),
      );
      await _loadAdminSources();
      if (!mounted) return;
      final total = result['total'] ?? _sources.length;
      final added = result['added'] ?? 0;
      _message(
        'Catálogo actualizado: $total / 120 listas. '
        'Se añadieron $added fuentes nuevas. '
        'Todas las importaciones se procesan en segundo plano.',
      );
    } catch (error) {
      _message('No se pudo completar el catálogo de 120 listas: ' + error.toString());
    } finally {
      if (!automatic && mounted) setState(() => _working = false);
    }
  }

  Future<void> _addGeneralPreset() async {
    if (_sources.length >= maxChannelPlaylistSources) {
      _message('Has alcanzado el límite de $maxChannelPlaylistSources listas.');
      return;
    }
    final preset = channelPlaylistPresets.firstWhere(
      (item) => item.url == _selectedGeneralPresetUrl,
      orElse: () => channelPlaylistPresets.first,
    );
    if (containsChannelPlaylistUrl(
      _sources.map((source) => source.url),
      preset.url,
    )) {
      _message('Esta lista ya está registrada en tu catálogo.');
      return;
    }
    setState(() => _working = true);
    try {
      // addPlaylist ya pone esta fuente en cola en Cloudflare; no volver a
      // procesar las otras 99 listas por añadir una sola.
      await _service.addPlaylist(url: preset.url, label: preset.label);
      final sources = await _service.fetchSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _sourcesError = null;
      });
      await _saveLocalAdminSnapshot(saveChannels: false, saveSources: true);
      _message('Lista añadida: ' + preset.label + '. Se importará en segundo plano y se publicarán solo canales deportivos compatibles.');
    } catch (error) {
      _message('No se pudo añadir la lista: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  bool get _hasIptvOrgGlobalIndex => containsChannelPlaylistUrl(
        _sources.map((source) => source.url),
        iptvOrgGlobalIndexPlaylistUrl,
      );

  Future<void> _addIptvOrgGlobalIndex({bool automatic = false}) async {
    if (_working && !automatic) return;
    if (_sources.length >= maxChannelPlaylistSources) {
      if (!automatic) _message('Ya están registradas las 120 listas.');
      return;
    }
    if (_hasIptvOrgGlobalIndex) {
      if (!automatic) _message('El índice índice global de IPTV-org ya está registrado.');
      return;
    }

    if (!automatic && mounted) setState(() => _working = true);
    try {
      await _service.addPlaylist(
        url: iptvOrgGlobalIndexPlaylistUrl,
        label: iptvOrgGlobalIndexPlaylistLabel,
      );
      // addPlaylist pone esta fuente individual en cola en el Worker.
      // No ejecutar refreshSources: reimportaría las otras 99 listas.
      final sources = await _service.fetchSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _visibleSourceCount = _visibleSourceCount.clamp(0, sources.length);
        _sourcesError = null;
      });
      await _saveLocalAdminSnapshot(saveChannels: false, saveSources: true);
      _message(
        'Índice índice global de IPTV-org añadido: ${_sources.length}/120 listas. '
        'Los canales se importarán por lotes en segundo plano.',
      );
    } catch (error) {
      if (mounted) {
        _message('No se pudo añadir el índice índice global de IPTV-org: ' + error.toString());
      }
    } finally {
      if (!automatic && mounted) setState(() => _working = false);
    }
  }

  Future<void> _refreshSources() async {
    setState(() => _working = true);
    try {
      await _service.refreshSources();
      await _loadAdmin(showLoading: false);
      _message('Se solicitó reimportar todas las listas guardadas. Se conservarán los canales deportivos y generales; el inventario se actualizará por bloques.');
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editPlaylistSource(ChannelPlaylistSource source) async {
    if (_working) return;
    final labelController = TextEditingController(text: source.label);
    final urlController = TextEditingController(text: source.url);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _channelPanel,
        title: const Text(
          'Editar lista IPTV',
          style: TextStyle(color: _channelCyan, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: labelController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre de la lista'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'URL HTTPS de la lista',
                  hintText: 'https://...',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _channelCyan),
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
    final label = labelController.text.trim();
    final candidateUrl = urlController.text.trim();
    labelController.dispose();
    urlController.dispose();
    if (confirmed != true || !mounted) return;

    final uri = Uri.tryParse(candidateUrl);
    if (label.isEmpty || label.length > 80) {
      _message('El nombre debe tener entre 1 y 80 caracteres.');
      return;
    }
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _message('Introduce una URL HTTPS pública válida.');
      return;
    }
    if (containsChannelPlaylistUrl(
      _sources
          .where((item) => item.id != source.id)
          .map((item) => item.url),
      uri.toString(),
    )) {
      _message('Otra lista ya utiliza esa URL.');
      return;
    }

    setState(() => _working = true);
    try {
      await _service.updatePlaylistSource(
        id: source.id,
        url: uri.toString(),
        label: label,
      );
      await _loadAdmin(showLoading: false);
      if (!mounted) return;
      _message('Lista actualizada. Se volverá a importar en segundo plano.');
    } catch (error) {
      _message('No se pudo actualizar la lista: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removePlaylistSource(ChannelPlaylistSource source) async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _channelPanel,
        title: const Text(
          'Quitar lista registrada',
          style: TextStyle(color: _channelPink),
        ),
        content: Text(
          '¿Quieres quitar "' + source.label +
              '" y detener sus futuras actualizaciones? Los canales ya importados se conservarán y seguirán pudiendo administrarse por separado.',
          style: const TextStyle(color: _channelMuted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _channelPink),
            child: const Text('QUITAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.deletePlaylistSource(id: source.id);
      if (!mounted) return;
      setState(() {
        _sources.removeWhere((item) => item.id == source.id);
      });
      await _saveLocalAdminSnapshot(saveChannels: false, saveSources: true);
      _message('Lista quitada. Los canales ya importados se conservaron.');
    } catch (error) {
      _message('No se pudo quitar la lista: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _retryPlaylistSource(ChannelPlaylistSource source) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _service.retryPlaylistSource(id: source.id);
      final sources = await _service.fetchSources();
      if (!mounted) return;
      setState(() => _sources = sources);
      _message('Reintento solicitado para "' + source.label + '".');
    } catch (error) {
      _message('No se pudo reintentar la lista: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _previewChannelInAdmin(SportsChannel channel) {
    setState(() {
      _previewChannel = channel;
      _diagnosticResult = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_adminScrollController.hasClients) return;
      _adminScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _diagnosePreviewChannel() async {
    final channel = _previewChannel;
    if (channel == null || _diagnosingPreview) return;
    setState(() {
      _diagnosingPreview = true;
      _diagnosticResult = null;
    });
    try {
      final result = await _service.diagnoseStream(channel.url);
      if (!mounted) return;
      setState(() => _diagnosticResult = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _diagnosticResult = 'No se pudo completar el diagnóstico: ' + error.toString());
    } finally {
      if (mounted) setState(() => _diagnosingPreview = false);
    }
  }

  Future<void> _toggleVisibility(SportsChannel channel) async {
    if (_working) return;
    final next = !channel.visible;
    setState(() => _working = true);
    try {
      await _service.setVisibility(channel.id, visible: next);
      await _updateLocalIptvChannel(channel, visible: next);
      _message(next ? 'Canal marcado como visible.' : 'Canal ocultado.');
    } catch (error) {
      _message('No se pudo cambiar la visibilidad: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _updateLocalIptvChannel(
    SportsChannel channel, {
    bool? visible,
    String? language,
  }) async {
    final updated = channel.copyWith(visible: visible, language: language);
    final next = _iptvChannels
        .map((item) => item.id == channel.id ? updated : item)
        .toList(growable: false);
    setState(() {
      _iptvChannels = next;
      _channels = List<SportsChannel>.from(next);
      if (_iptvSelectedChannel?.id == channel.id) {
        _iptvSelectedChannel = updated;
      }
    });
    await _iptvStore.save(
      email: (_email ?? _service.signedInEmail ?? '').trim(),
      channels: next,
      sources: _sources,
      complete: _iptvLoaded,
      nextOffset: _iptvNextOffset,
    );
  }

  Future<void> _deleteChannel(SportsChannel channel) async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _channelPanel,
        title: const Text(
          'ELIMINAR CANAL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Se eliminará "${channel.name}" del catálogo y se bloqueará su URL para que las próximas importaciones no lo vuelvan a agregar. Esta acción no se puede deshacer desde la APK.',
          style: const TextStyle(color: _channelMuted, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _channelPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      await _service.deleteChannel(channel.id);
      if (!mounted) return;
      if (_previewChannel?.id == channel.id) {
        setState(() {
          _previewChannel = null;
          _diagnosticResult = null;
        });
      }
      await _loadAdmin(showLoading: false);
      if (!mounted) return;
      _message('Canal eliminado. Su URL quedó bloqueada para futuras importaciones.');
    } catch (error) {
      _message('No se pudo eliminar el canal: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _setChannelSportsClassification(
    SportsChannel channel,
  ) async {
    if (_working) return;
    final next = !channel.isSports;
    setState(() => _working = true);
    try {
      await _service.setChannelSportsClassification(
        channel.id,
        isSports: next,
      );
      await _loadAdmin(showLoading: false);
      _message(next
          ? 'Canal clasificado como deportivo. Ya puedes publicarlo.'
          : 'Canal clasificado como general y ocultado de Canales deportivos.');
    } catch (error) {
      _message('No se pudo cambiar la clasificación: ' + error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _setChannelLanguage(
    SportsChannel channel,
    String language,
  ) async {
    try {
      await _service.setLanguage(channel.id, language: language);
      await _updateLocalIptvChannel(channel, language: language);
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
      case 'importing':
        return 'IMPORTANDO…';
      case 'imported':
        return 'ACTUALIZADA';
      case 'error':
        return 'ERROR: ' + source.lastError;
      default:
        return source.status.toUpperCase();
    }
  }

  Color _sourceStatusColor(ChannelPlaylistSource source) {
    switch (source.status) {
      case 'error':
        return _channelPink;
      case 'importing':
      case 'queued':
        return _channelCyan;
      default:
        return _channelGreen;
    }
  }

  String? _sourceLastUpdated(ChannelPlaylistSource source) {
    if (source.lastImportedAt.isEmpty) return null;
    final parsed = DateTime.tryParse(source.lastImportedAt);
    if (parsed == null) return source.lastImportedAt;
    final local = parsed.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'Última importación: ' +
        twoDigits(local.day) + '/' +
        twoDigits(local.month) + '/' +
        local.year.toString() + ' ' +
        twoDigits(local.hour) + ':' +
        twoDigits(local.minute);
  }

  Widget _licenseMetric(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _channelPanel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(110)),
      ),
      child: Column(
        children: <Widget>[
          Text(value, style: TextStyle(color: accent, fontSize: 15,
            fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: _channelMuted, fontSize: 7,
              fontWeight: FontWeight.w900)),
        ],
      ),
    );
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
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
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
                  sport ? 'DEPORTIVO' : 'GENERAL / SIN CLASIFICAR',
                  style: TextStyle(
                    color: sport ? _channelGreen : _channelMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    tooltip: 'ACCIONES DEL CANAL',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    color: _channelPanel,
                    onSelected: (action) {
                      if (action == 'preview') {
                        _previewChannelInAdmin(channel);
                      } else if (action == 'classification') {
                        unawaited(_setChannelSportsClassification(channel));
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'preview',
                        child: Text('PROBAR CANAL'),
                      ),
                      PopupMenuItem<String>(
                        value: 'classification',
                        child: Text(
                          sport ? 'MARCAR COMO GENERAL' : 'MARCAR COMO DEPORTIVO',
                        ),
                      ),
                    ],
                    icon: const Icon(
                      Icons.more_vert_rounded,
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
            onPressed: sport && !_working
                ? () => _toggleVisibility(channel)
                : null,
            icon: Icon(
              channel.visible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: channel.visible ? _channelGreen : _channelMuted,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar permanentemente',
            visualDensity: VisualDensity.compact,
            onPressed: _working ? null : () => _deleteChannel(channel),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: _channelPink,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }


  void _openAdminSection() {
    if (mounted) {
      setState(() {
        _showIptvSection = false;
              });
    }
  }

  void _openIptvSection() {
    if (mounted) {
      setState(() {
        _showIptvSection = true;
              });
    }
    if (!_iptvLoaded && !_iptvLoading) unawaited(_loadAllIptvChannels());
  }

  Future<void> _loadAllIptvChannels({bool force = false}) async {
    if (_iptvLoading || (_iptvLoaded && !force)) return;
    final requestId = ++_iptvRequestId;
    final email = (_email ?? _service.signedInEmail ?? '').trim();
    if (email.isEmpty) {
      setState(() => _iptvError = 'Inicia sesión para descargar las listas IPTV.');
      return;
    }

    setState(() {
      _iptvLoading = true;
      _iptvError = null;
    });

    var allChannels = <SportsChannel>[];
    var offset = 0;
    try {
      final cached = await _iptvStore.load(email: email);
      if (!mounted || requestId != _iptvRequestId) return;

      if (!force && cached != null) {
        allChannels = List<SportsChannel>.from(cached.channels);
        offset = cached.nextOffset;
        _iptvNextOffset = offset;
        _iptvCacheComplete = cached.complete;
        if (cached.sources.isNotEmpty) {
          _sources = List<ChannelPlaylistSource>.from(cached.sources);
        }
        setState(() {
          _iptvChannels = List<SportsChannel>.unmodifiable(allChannels);
          _iptvLoaded = cached.complete;
        });
        if (cached.complete) return;
      }

      // La importación se reanuda desde el último bloque persistido.
      // Se conserva cada fila tal como la entrega el catálogo, también si
      // dos listas contienen registros repetidos.
      while (true) {
        final page = await _service.fetchAdminChannelPage(
          offset: offset,
          limit: channelAdminCatalogPageSize,
        );
        if (!mounted || requestId != _iptvRequestId) return;
        if (page.channels.isEmpty && page.hasMore) {
          throw const ChannelCatalogException(
            'El servidor indicó que hay más canales, pero no entregó el siguiente bloque.',
          );
        }

        allChannels.addAll(page.channels);
        final nextOffset = page.offset + page.channels.length;
        if (nextOffset < offset || (page.hasMore && nextOffset <= offset)) {
          throw const ChannelCatalogException(
            'La paginación del catálogo no avanzó; se conserva el último bloque descargado.',
          );
        }

        _iptvNextOffset = nextOffset;
        setState(() {
          _iptvChannels = List<SportsChannel>.unmodifiable(allChannels);
          _iptvLoaded = false;
        });
        await _iptvStore.save(
          email: email,
          channels: allChannels,
          sources: _sources,
          complete: false,
          nextOffset: nextOffset,
        );

        if (!page.hasMore) break;
        if (nextOffset >= channelCatalogMaxOffset) {
          throw const ChannelCatalogException(
            'Se alcanzó el límite técnico de paginación. El progreso ya quedó guardado en el teléfono.',
          );
        }
        offset = nextOffset;
      }

      if (!mounted || requestId != _iptvRequestId) return;
      await _iptvStore.save(
        email: email,
        channels: allChannels,
        sources: _sources,
        complete: true,
        nextOffset: _iptvNextOffset,
      );
      setState(() {
        _iptvChannels = List<SportsChannel>.unmodifiable(allChannels);
        _channels = List<SportsChannel>.from(allChannels);
        _catalogTotal = allChannels.length;
        _catalogTotalIsEstimate = false;
        _nextAdminOffset = allChannels.length;
        _hasMore = false;
        _iptvLoaded = true;
        _iptvCacheComplete = true;
        if (_iptvSelectedChannel != null) {
          _iptvSelectedChannel = allChannels.cast<SportsChannel?>().firstWhere(
                (item) => item?.id == _iptvSelectedChannel!.id,
                orElse: () => _iptvSelectedChannel,
              );
        }
      });
      await _saveLocalAdminSnapshot(saveChannels: false, saveSources: true);
    } catch (error) {
      if (!mounted || requestId != _iptvRequestId) return;
      setState(() {
        _iptvError = error.toString();
        _iptvLoaded = false;
        _iptvChannels = List<SportsChannel>.unmodifiable(allChannels);
      });
    } finally {
      if (mounted && requestId == _iptvRequestId) {
        setState(() => _iptvLoading = false);
      }
    }
  }

  Widget _buildAdminSectionSwitcher() {
    Widget tab({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color: selected ? _channelCyan.withAlpha(24) : _channelPanel,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: selected ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: selected ? _channelCyan : _channelLine.withAlpha(130)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 17, color: selected ? _channelCyan : _channelMuted),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? _channelCyan : _channelMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
      child: Row(
        children: <Widget>[
          tab(
            label: 'ADMINISTRACIÓN',
            icon: Icons.admin_panel_settings_rounded,
            selected: !_showIptvSection,
            onTap: _openAdminSection,
          ),
          const SizedBox(width: 8),
          tab(
            label: 'IPTV',
            icon: Icons.live_tv_rounded,
            selected: _showIptvSection,
            onTap: _openIptvSection,
          ),
        ],
      ),
    );
  }

  Widget _buildIptvAddListCard() {
    return _adminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'AÑADIR CANALES Y LISTAS IPTV',
            style: TextStyle(color: _channelCyan, fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _labelController,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            decoration: const InputDecoration(
              labelText: 'Nombre de la lista',
              hintText: 'Ej. Lista deportiva autorizada',
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            decoration: const InputDecoration(
              labelText: 'URL HTTPS de la lista IPTV',
              hintText: 'M3U/M3U8, PLS, XSPF, XML/ASX, JSON, CSV o TXT',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 5),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _rightsConfirmed,
            activeColor: _channelGreen,
            title: const Text(
              'Confirmo que tengo derecho a usar y distribuir estas señales.',
              style: TextStyle(color: _channelMuted, fontSize: 9, height: 1.3),
            ),
            onChanged: _working ? null : (value) => setState(() => _rightsConfirmed = value ?? false),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working || _sources.length >= maxChannelPlaylistSources ? null : _addPlaylist,
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(_sources.length >= maxChannelPlaylistSources ? 'LÍMITE DE LISTAS COMPLETO' : 'AGREGAR CANALES DESDE ESTA LISTA'),
              style: FilledButton.styleFrom(backgroundColor: _channelGreen, foregroundColor: _channelBg),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedSportsPresetUrl,
            isExpanded: true,
            dropdownColor: _channelPanel2,
            decoration: const InputDecoration(labelText: 'Lista deportiva predefinida'),
            items: channelSportsPlaylistPresets.map((preset) => DropdownMenuItem<String>(
              value: preset.url,
              child: Text(preset.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(growable: false),
            onChanged: _working ? null : (value) => setState(() => _selectedSportsPresetUrl = value ?? channelSportsPlaylistPresets.first.url),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working || _sources.length >= maxChannelPlaylistSources ? null : _addSportsPreset,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('AGREGAR LISTA DEPORTIVA'),
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            initialValue: _selectedGeneralPresetUrl,
            isExpanded: true,
            dropdownColor: _channelPanel2,
            decoration: const InputDecoration(labelText: 'Lista general predefinida'),
            items: channelPlaylistPresets.map((preset) => DropdownMenuItem<String>(
              value: preset.url,
              child: Text(preset.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(growable: false),
            onChanged: _working ? null : (value) => setState(() => _selectedGeneralPresetUrl = value ?? channelPlaylistPresets.first.url),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working || _sources.length >= maxChannelPlaylistSources ? null : _addGeneralPreset,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('AGREGAR LISTA GENERAL'),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _fillPlaylistCatalogTo120,
              icon: const Icon(Icons.cloud_download_rounded),
              label: Text(_sources.length >= maxChannelPlaylistSources ? '120 LISTAS REGISTRADAS' : 'COMPLETAR CATÁLOGO HASTA 120 LISTAS'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _refreshSources,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('REIMPORTAR TODAS LAS LISTAS GUARDADAS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIptvScreen() {
    final query = _iptvSearchController.text.trim().toLowerCase();
    final rows = _iptvChannels.where((channel) {
      return query.isEmpty ||
          (channel.name + ' ' + channel.groupTitle).toLowerCase().contains(query);
    }).toList(growable: false);
    final sports = _iptvChannels.where((channel) => channel.isSports).length;
    final general = _iptvChannels.length - sports;
    final totalLabel = _iptvLoaded
        ? _iptvChannels.length.toString()
        : 'CARGADOS ' + _iptvChannels.length.toString();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
          child: _adminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(children: <Widget>[
                  Icon(Icons.live_tv_rounded, color: _channelCyan, size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'REPRODUCTOR IPTV',
                      style: TextStyle(
                        color: _channelCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 7),
                if (_iptvSelectedChannel != null)
                  Text(
                    _iptvSelectedChannel!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ChannelInlinePlayer(
                  key: _iptvPlayerKey,
                  channel: _iptvSelectedChannel,
                  showProxyControls: false,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey<String>('channel-admin-iptv-list'),
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 20),
            itemCount: rows.length + _sources.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _adminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        const Expanded(
                          child: Text(
                            '120 LISTAS IPTV · TODOS LOS CANALES',
                            style: TextStyle(
                              color: _channelGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          totalLabel,
                          key: const ValueKey<String>('iptv-channel-total'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ]),
                      Row(children: <Widget>[
                        Expanded(
                          child: _licenseMetric(
                            'DEPORTIVOS',
                            sports.toString(),
                            _channelGreen,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _licenseMetric(
                            'GENERALES',
                            general.toString(),
                            _channelCyan,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _licenseMetric(
                            'LISTAS',
                            _sources.length.toString() + '/120',
                            _channelYellow,
                          ),
                        ),
                      ]),
                      if (_iptvLoading) ...<Widget>[
                        const SizedBox(height: 7),
                        const LinearProgressIndicator(
                          minHeight: 3,
                          color: _channelCyan,
                          backgroundColor: _channelPanel2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Descargando bloques. Guardados en este teléfono: ${_iptvChannels.length} canales.',
                          style: const TextStyle(
                            color: _channelMuted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                      if (_iptvError != null)
                        Text(
                          _iptvError!,
                          style: const TextStyle(
                            color: _channelPink,
                            fontSize: 9,
                          ),
                        ),
                      if (_iptvLoaded)
                        const Text(
                          'Descarga completa y guardada en el almacenamiento del teléfono. No será necesario descargarla de nuevo.',
                          style: TextStyle(
                            color: _channelGreen,
                            fontSize: 9,
                          ),
                        ),
                      if (_sourcesError != null && _sources.isNotEmpty)
                        Text(
                          _sourcesError!,
                          style: const TextStyle(
                            color: _channelMuted,
                            fontSize: 8,
                          ),
                        ),
                      const SizedBox(height: 7),
                      TextField(
                        key: const ValueKey<String>('iptv-search-field'),
                        controller: _iptvSearchController,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Buscar canal por nombre',
                          hintText: 'ESPN, FOX, beIN, etc.',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _channelCyan,
                          ),
                          suffixIcon: _iptvSearchController.text.isEmpty
                              ? null
                              : IconButton(
                                  key: const ValueKey<String>('iptv-search-clear'),
                                  tooltip: 'Mostrar todos los canales',
                                  onPressed: () {
                                    _iptvSearchController.clear();
                                    FocusScope.of(context).unfocus();
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _channelMuted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Mostrando ${rows.length} de ${_iptvChannels.length} canales.',
                        style: const TextStyle(
                          color: _channelMuted,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (index <= rows.length) {
                final channel = rows[index - 1];
                final selected = _iptvSelectedChannel?.id == channel.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? _channelCyan.withAlpha(24)
                        : _channelPanel,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => setState(() => _iptvSelectedChannel = channel),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: selected
                                ? _channelCyan
                                : _channelLine.withAlpha(100),
                          ),
                        ),
                        child: Row(children: <Widget>[
                          SizedBox(
                            width: 25,
                            child: Text(
                              index.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _channelCyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _ChannelLogo(channel: channel, size: 34),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  channel.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  (channel.groupTitle.isEmpty
                                          ? 'SIN GRUPO'
                                          : channel.groupTitle) +
                                      (channel.isSports
                                          ? ' · DEPORTIVO'
                                          : ' · GENERAL'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _channelMuted,
                                    fontSize: 8,
                                  ),
                                ),
                                ChannelLanguageBadge(
                                  language: channel.language,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 94,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                key: ValueKey<String>(
                                  'iptv-language-${channel.id}',
                                ),
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
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                                items: const <DropdownMenuItem<String>>[
                                  DropdownMenuItem<String>(
                                    value: 'unknown',
                                    child: Text('Auto'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'es',
                                    child: Text('Español'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'en',
                                    child: Text('Inglés'),
                                  ),
                                ],
                                onChanged: _working
                                    ? null
                                    : (value) {
                                        if (value != null &&
                                            value != channel.language) {
                                          unawaited(
                                            _setChannelLanguage(channel, value),
                                          );
                                        }
                                      },
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'iptv-add-channel-${channel.id}',
                            ),
                            tooltip: channel.visible
                                ? 'Ocultar canal'
                                : 'Hacer visible el canal',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            onPressed: _working
                                ? null
                                : () => _toggleVisibility(channel),
                            icon: Icon(
                              channel.visible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: channel.visible
                                  ? _channelGreen
                                  : _channelMuted,
                              size: 19,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }

              final source = _sources[index - rows.length - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _adminCard(
                  child: Row(children: <Widget>[
                    const Icon(
                      Icons.playlist_play_rounded,
                      color: _channelCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            source.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _sourceStatus(source) +
                                ' · ' +
                                source.importedCount.toString() +
                                ' canales procesados',
                            style: const TextStyle(
                              color: _channelMuted,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCatalogSection() {
    final loadedSports = _channels.where((channel) => channel.isSports).length;
    final loadedGeneral = _channels.length - loadedSports;
    final totalLabel = _catalogTotalIsEstimate
        ? 'MÁS DE ' + _catalogTotal.toString()
        : _catalogTotal.toString() + ' CANALES';

    return _adminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'INVENTARIO COMPLETO DE CANALES',
                  style: TextStyle(
                    color: _channelCyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar inventario',
                onPressed: _loading ? null : _loadAdmin,
                icon: const Icon(Icons.sync_rounded, color: _channelGreen),
              ),
            ],
          ),
          Text(
            'Incluye canales deportivos y generales de todas las listas importadas. Desliza por el inventario y carga los siguientes bloques para confirmar el total exacto. Solo los deportivos pueden publicarse en Canales deportivos.',
            style: const TextStyle(
              color: _channelMuted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _licenseMetric(
                  'TOTAL EN CATÁLOGO',
                  totalLabel,
                  _channelCyan,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _licenseMetric(
                  'CARGADOS',
                  _channels.length.toString(),
                  Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: _licenseMetric(
                  'DEPORTIVOS',
                  loadedSports.toString(),
                  _channelGreen,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _licenseMetric(
                  'GENERALES',
                  loadedGeneral.toString(),
                  _channelYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : _refreshSources,
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: const Text('REIMPORTAR LISTAS GUARDADAS · TODOS LOS CANALES'),
              style: FilledButton.styleFrom(
                backgroundColor: _channelGreen,
                foregroundColor: _channelBg,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Vuelve a procesar las listas guardadas por lotes para incorporar canales generales que antes se filtraban. No elimina listas ni canales existentes.',
            style: TextStyle(
              color: _channelMuted,
              fontSize: 9,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _searchChannels(),
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Buscar en todos los canales',
              hintText: 'ESPN, noticias, entretenimiento...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _channelCyan,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: _loading ? null : _clearChannelSearch,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _channelMuted,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Buscar canal',
                    onPressed: _loading ? null : _searchChannels,
                    icon: const Icon(
                      Icons.search_rounded,
                      color: _channelGreen,
                    ),
                  ),
                ],
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _loadMore,
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  'CARGAR SIGUIENTE BLOQUE · ' + _channels.length.toString() +
                      (_catalogTotalIsEstimate ? '+' : ''),
                ),
              ),
            ),
          if (!_hasMore && _channels.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Inventario completo cargado. El total mostrado ya es exacto.',
                style: TextStyle(
                  color: _channelGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
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
        backgroundColor: const Color(0xFF07090D),
        title: const AppSectionTitle(
          icon: Icons.live_tv_rounded,
          title: '120 LISTAS IPTV',
          accent: _channelCyan,
          subtitle: 'CATÁLOGO LOCAL · DEPORTE TOTAL 360°',
        ),
        actions: <Widget>[
          if (loggedIn)
            IconButton(
              onPressed: _working ? null : _signOut,
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout_rounded, color: _channelMuted),
            ),
        ],
      ),
      body: !loggedIn
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: _adminCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.live_tv_rounded,
                        color: _channelCyan,
                        size: 52,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'CATÁLOGO IPTV PRIVADO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inicia sesión para descargar las 120 listas y conservar todos sus canales en este teléfono.',
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
          : SafeArea(child: _buildIptvScreen()),
    );
  }
}
