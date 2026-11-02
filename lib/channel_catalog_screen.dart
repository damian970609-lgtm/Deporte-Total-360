import 'package:flutter/material.dart';

import 'channel_catalog_service.dart';

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
                    hintText: 'https://proveedor-autorizado.example/epg.xml',
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
