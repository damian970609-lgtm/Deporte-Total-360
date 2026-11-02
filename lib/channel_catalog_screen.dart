import 'package:flutter/material.dart';

import 'agenda_screen.dart';
import 'channel_catalog_service.dart';

class ChannelCatalogScreen extends StatefulWidget {
  const ChannelCatalogScreen({super.key});

  @override
  State<ChannelCatalogScreen> createState() => _ChannelCatalogScreenState();
}

class _ChannelCatalogScreenState extends State<ChannelCatalogScreen> {
  List<TvCatalogChannel> _channels = const <TvCatalogChannel>[];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _group = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final channels = await ChannelCatalogService.instance.loadChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loading = false;
        if (_group != 'Todos' && !channels.any((channel) => channel.group == _group)) {
          _group = 'Todos';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString(); });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ChannelCatalogSettingsScreen()),
    );
    if (mounted) await _load();
  }

  List<TvCatalogChannel> get _visibleChannels {
    final query = _query.trim().toLowerCase();
    return _channels.where((channel) {
      if (_group != 'Todos' && channel.group != _group) return false;
      if (query.isNotEmpty &&
          !channel.name.toLowerCase().contains(query) &&
          !channel.group.toLowerCase().contains(query)) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const muted = Color(0xFFA9BDD6);
    final groups = <String>{
      'Todos',
      ..._channels.map((channel) => channel.group).where((group) => group.isNotEmpty),
    }.toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFF030814),
      appBar: AppBar(
        title: const Text('CANALES TV', style: TextStyle(color: cyan, fontSize: 14, fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Configurar listas M3U y EPG',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded, color: cyan),
          ),
          IconButton(
            tooltip: 'Actualizar canales',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: cyan),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: cyan))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF3155), size: 40),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _openSettings, icon: const Icon(Icons.playlist_add_rounded), label: const Text('Configurar fuentes')),
                      ],
                    ),
                  ),
                )
              : _channels.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.live_tv_rounded, color: cyan, size: 48),
                            const SizedBox(height: 12),
                            const Text('Todavía no hay canales configurados', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 8),
                            const Text('Añade una lista M3U autorizada para ver aquí tus canales y abrirlos en el reproductor nativo.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
                            const SizedBox(height: 14),
                            FilledButton.icon(onPressed: _openSettings, icon: const Icon(Icons.playlist_add_rounded), label: const Text('CONFIGURAR CANALES')),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: TextField(
                            onChanged: (value) => setState(() => _query = value),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Buscar canal o categoría…',
                              prefixIcon: const Icon(Icons.search_rounded, color: cyan),
                              filled: true,
                              fillColor: const Color(0xFF071326),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            scrollDirection: Axis.horizontal,
                            itemCount: groups.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 7),
                            itemBuilder: (context, index) => ChoiceChip(
                              label: Text(groups[index]),
                              selected: _group == groups[index],
                              onSelected: (_) => setState(() => _group = groups[index]),
                              selectedColor: const Color(0xFF087BFF),
                              backgroundColor: const Color(0xFF071326),
                              labelStyle: TextStyle(color: _group == groups[index] ? Colors.white : muted, fontSize: 11, fontWeight: FontWeight.w800),
                              side: BorderSide(color: _group == groups[index] ? cyan : const Color(0xFF123D65)),
                              showCheckmark: false,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            children: <Widget>[
                              const Expanded(child: Text('LISTA DE CANALES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                              Text('${_visibleChannels.length} canales', style: const TextStyle(color: muted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _visibleChannels.isEmpty
                              ? const Center(child: Text('No hay canales en esta categoría.', style: TextStyle(color: muted)))
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                  itemCount: _visibleChannels.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                                  itemBuilder: (context, index) {
                                    final channel = _visibleChannels[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF071326),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF123D65)),
                                      ),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFF102B49),
                                          child: Icon(Icons.live_tv_rounded, color: cyan),
                                        ),
                                        title: Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                                        subtitle: Text(channel.group.isEmpty ? 'TV en directo' : channel.group, style: const TextStyle(color: muted, fontSize: 10)),
                                        trailing: IconButton(
                                          tooltip: 'Reproducir canal',
                                          onPressed: () => Navigator.of(context).push<void>(
                                            MaterialPageRoute<void>(
                                              builder: (_) => AgendaVideoPlayerScreen(
                                                title: channel.name,
                                                source: MatchStreamSource(
                                                  name: channel.name,
                                                  url: channel.url,
                                                  httpHeaders: channel.httpHeaders,
                                                ),
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(Icons.play_circle_fill_rounded, color: cyan, size: 30),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}

class ChannelCatalogSettingsScreen extends StatefulWidget {
  const ChannelCatalogSettingsScreen({super.key});
  @override
  State<ChannelCatalogSettingsScreen> createState() => _ChannelCatalogSettingsScreenState();
}

class _ChannelCatalogSettingsScreenState extends State<ChannelCatalogSettingsScreen> {
  final _playlistController = TextEditingController();
  final _epgController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _message;
  int? _channelCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await ChannelCatalogService.instance.loadConfig();
      if (!mounted) return;
      _playlistController.text = config.playlistUrl;
      _epgController.text = config.epgUrl;
    } catch (_) {
      if (mounted) setState(() => _message = 'No se pudo leer la configuración guardada.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _message = null; _channelCount = null; });
    try {
      await ChannelCatalogService.instance.saveConfig(
        playlistUrl: _playlistController.text,
        epgUrl: _epgController.text,
      );
      if (mounted) setState(() => _message = 'Fuentes guardadas. La agenda buscará programas coincidentes.');
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() { _saving = true; _message = null; _channelCount = null; });
    try {
      await ChannelCatalogService.instance.saveConfig(
        playlistUrl: _playlistController.text,
        epgUrl: _epgController.text,
      );
      final count = await ChannelCatalogService.instance.testPlaylist();
      if (!mounted) return;
      setState(() {
        _channelCount = count;
        _message = count == 0
            ? 'La lista se abrió, pero no contiene canales HLS/DASH compatibles.'
            : 'Catálogo leído correctamente.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _playlistController.dispose();
    _epgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const muted = Color(0xFFA9BDD6);
    return Scaffold(
      backgroundColor: const Color(0xFF030814),
      appBar: AppBar(
        title: const Text('FUENTES DE CANALES', style: TextStyle(color: cyan, fontSize: 14, fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: cyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text(
                  'Conecta una lista M3U y una guía XMLTV de un proveedor que te autorice a reproducir esas señales. La guía permite asociar cada programa con el partido de la agenda; sin EPG no se puede confirmar qué evento está emitiendo un canal.',
                  style: TextStyle(color: muted, height: 1.5, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _playlistController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'URL HTTPS de lista M3U',
                    hintText: 'https://proveedor-autorizado.example/lista.m3u',
                    prefixIcon: Icon(Icons.playlist_play_rounded, color: cyan),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _epgController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'URL HTTPS de guía XMLTV / EPG',
                    hintText: 'https://proveedor-autorizado.example/epg.xml o epg.xml.gz',
                    prefixIcon: Icon(Icons.event_note_rounded, color: cyan),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071326),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF123D65)),
                  ),
                  child: const Text(
                    'La app acepta fuentes HTTPS configuradas aquí y solo asocia programas cuyo título coincide con los dos equipos del evento. No extrae enlaces de otras aplicaciones ni de reproductores protegidos.',
                    style: TextStyle(color: muted, height: 1.45, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: const Text('GUARDAR'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton.icon(onPressed: _saving ? null : _test, icon: const Icon(Icons.wifi_tethering_rounded), label: const Text('PROBAR LISTA'))),
                  ],
                ),
                if (_saving) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(color: cyan),
                ],
                if (_channelCount != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('Canales HLS/DASH compatibles: $_channelCount', style: const TextStyle(color: cyan, fontWeight: FontWeight.w900)),
                ],
                if (_message != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_message!, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                ],
              ],
            ),
    );
  }
}
