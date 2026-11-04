import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import 'automatic_live_service.dart';

const Color _tvBg = Color(0xFF030814);
const Color _tvPanel = Color(0xFF071326);
const Color _tvLine = Color(0xFF123D65);
const Color _tvCyan = Color(0xFF00E5FF);
const Color _tvGreen = Color(0xFF39FF9C);
const Color _tvPink = Color(0xFFFF28CF);
const Color _tvMuted = Color(0xFFA9BDD6);

class TelevizoIntegrationScreen extends StatefulWidget {
  const TelevizoIntegrationScreen({super.key});

  @override
  State<TelevizoIntegrationScreen> createState() =>
      _TelevizoIntegrationScreenState();
}

class _TelevizoIntegrationScreenState extends State<TelevizoIntegrationScreen> {
  final AutomaticLiveService _service = AutomaticLiveService();

  AutoLiveSettings? _settings;
  AutoLiveCatalog? _catalog;
  bool _loading = true;
  bool _opening = false;
  String _status = 'Preparando listas guardadas…';
  String? _error;
  String? _warning;
  int _playlistCount = 0;
  int _epgCount = 0;
  int _channelCount = 0;
  int _programmeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _warning = null;
        _status = 'Actualizando todas las fuentes…';
      });
    }

    try {
      final settings = await AutoLiveSettings.load();
      if (!mounted) return;

      setState(() {
        _settings = settings;
        _playlistCount =
            settings.playlistUrls.length + settings.localPlaylistTexts.length;
        _epgCount = settings.epgUrls.length;
        _status = 'Descargando listas M3U y guías EPG…';
      });

      final failedSources = <String>{};
      final catalog = await _service.loadCatalog(
        playlistUrl: settings.playlistUrls.join('\n'),
        epgUrl: settings.epgUrls.join('\n'),
        playlistTexts: settings.localPlaylistTexts,
        forceRefresh: true,
        downloadBatchSize: 4,
        batchPause: const Duration(milliseconds: 100),
        maxPlaylistBytes: 8 * 1024 * 1024,
        maxEpgBytes: 12 * 1024 * 1024,
        onChannelsLoaded: (channels) {
          if (!mounted) return;
          setState(() => _channelCount = channels.length);
        },
        onSourceError: (url, error) {
          final host = Uri.tryParse(url)?.host;
          failedSources.add(
            host == null || host.isEmpty ? 'Fuente desconocida' : host,
          );
        },
        onProgress: (phase, completed, total) {
          if (!mounted) return;
          final label = phase == 'LOCAL'
              ? 'Analizando listas guardadas'
              : phase == 'M3U'
                  ? 'Extrayendo listas M3U'
                  : 'Procesando guías EPG';
          setState(() => _status = '$label: $completed de $total');
        },
      );

      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _channelCount = catalog.channels.length;
        _programmeCount = catalog.programmes.length;
        _warning = failedSources.isEmpty
            ? null
            : '${failedSources.length} fuente(s) no respondieron o no contenían datos compatibles.';
        _status = catalog.channels.isEmpty
            ? 'No se encontraron canales directos compatibles.'
            : 'Catálogo unificado listo para Televizo.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _status = 'No se pudieron preparar todas las fuentes.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInTelevizo() async {
    final settings = _settings;
    final catalog = _catalog;
    if (settings == null || catalog == null || catalog.channels.isEmpty) {
      _showMessage(
        'Primero extrae las listas y comprueba que haya canales compatibles.',
      );
      return;
    }

    setState(() => _opening = true);
    try {
      final merged = AutomaticLiveService.buildMergedM3u(
        catalog,
        epgUrls: settings.epgUrls,
      );
      final channelEntries =
          RegExp(r'(?m)^#EXTINF:').allMatches(merged).length;
      if (channelEntries == 0) {
        _showMessage(
          'No hay enlaces multimedia directos para importar en Televizo.',
        );
        return;
      }

      final directory =
          await Directory.systemTemp.createTemp('dt360_televizo_');
      final file = File(directory.path + '/deporte-total-360.m3u');
      await file.writeAsString(merged, flush: true);

      final result = await OpenFilex.open(
        file.path,
        type: 'audio/x-mpegurl',
      );

      if (!mounted) return;
      if (result.type == ResultType.done) {
        _showMessage(
          'Lista preparada con ' +
              channelEntries.toString() +
              ' canales y ' +
              settings.epgUrls.length.toString() +
              ' referencias EPG. Selecciona Televizo si Android pregunta con qué aplicación abrirla.',
        );
      } else if (result.type == ResultType.noAppToOpen) {
        _showMessage(
          'Android no encontró una aplicación para abrir la lista. Instala Televizo y vuelve a intentarlo.',
        );
      } else {
        _showMessage(
          'No se pudo entregar la lista a Televizo: ' + result.message,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Error al preparar la lista para Televizo: ' + error.toString());
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _installTelevizo() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.ottplay.ottplay',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('No se pudo abrir Google Play en este dispositivo.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tvPanel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _tvLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: _tvMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messagePanel(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 11, height: 1.45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canImport = !_loading &&
        !_opening &&
        _catalog != null &&
        _catalog!.channels.isNotEmpty;

    return Scaffold(
      backgroundColor: _tvBg,
      appBar: AppBar(
        backgroundColor: _tvBg,
        foregroundColor: _tvCyan,
        title: const Text(
          'TELEVIZO · CENTRO IPTV',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar todas las listas y EPG',
            onPressed: _loading ? null : _loadSources,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _tvPanel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _tvLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TODAS TUS LISTAS EN UN SOLO REPRODUCTOR',
                    style: TextStyle(
                      color: _tvGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Damián APK reúne las listas y guías EPG que ya tienes guardadas y prepara una M3U unificada para abrirla con Televizo.',
                    style: TextStyle(
                      color: _tvMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _tvCyan,
                          ),
                        )
                      else
                        Icon(
                          _error == null
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _error == null ? _tvGreen : _tvPink,
                          size: 18,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(
                            color: _tvMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 2.25,
              children: [
                _metric(
                  'LISTAS M3U',
                  _playlistCount.toString(),
                  Icons.playlist_play_rounded,
                  _tvCyan,
                ),
                _metric(
                  'GUÍAS EPG',
                  _epgCount.toString(),
                  Icons.tv_rounded,
                  _tvPink,
                ),
                _metric(
                  'CANALES ÚNICOS',
                  _channelCount.toString(),
                  Icons.live_tv_rounded,
                  _tvGreen,
                ),
                _metric(
                  'PROGRAMAS EPG',
                  _programmeCount.toString(),
                  Icons.event_note_rounded,
                  _tvCyan,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _messagePanel(_error!, _tvPink),
            ],
            if (_warning != null) ...[
              const SizedBox(height: 10),
              _messagePanel(_warning!, Colors.orangeAccent),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canImport ? _openInTelevizo : null,
                icon: _opening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _tvBg,
                        ),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                label: Text(
                  _opening
                      ? 'PREPARANDO ARCHIVO M3U…'
                      : 'IMPORTAR TODAS LAS LISTAS EN TELEVIZO',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _tvGreen,
                  foregroundColor: _tvBg,
                  disabledBackgroundColor: _tvLine,
                  disabledForegroundColor: _tvMuted,
                ),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _installTelevizo,
                icon: const Icon(Icons.download_rounded),
                label: const Text(
                  'INSTALAR TELEVIZO DESDE GOOGLE PLAY',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tvCyan,
                  side: const BorderSide(color: _tvCyan),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _messagePanel(
              'La M3U incluye los canales directos compatibles sin duplicados y las direcciones de tus guías EPG. Televizo puede pedirte confirmar la importación. Las guías se consultan desde sus direcciones XMLTV; el archivo M3U no contiene copias internas de esos XML.',
              _tvMuted,
            ),
            const SizedBox(height: 10),
            const Text(
              'Si Android muestra una ventana para elegir aplicación, selecciona Televizo. Las páginas web, enlaces RTMP y señales protegidas no se convierten en enlaces directos reproducibles.',
              style: TextStyle(color: _tvMuted, fontSize: 10, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
