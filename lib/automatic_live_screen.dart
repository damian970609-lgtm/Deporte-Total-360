import 'dart:async';

import 'package:flutter/material.dart';

import 'automatic_live_service.dart';
import 'live_channels_screen.dart';

const Color _autoBg = Color(0xFF030814);
const Color _autoPanel = Color(0xFF071326);
const Color _autoLine = Color(0xFF123D65);
const Color _autoCyan = Color(0xFF00E5FF);
const Color _autoGreen = Color(0xFF39FF9C);
const Color _autoPink = Color(0xFFFF28CF);
const Color _autoMuted = Color(0xFFA9BDD6);

class AutomaticLiveScreen extends StatefulWidget {
  const AutomaticLiveScreen({super.key, required this.onOpenAgenda, this.isActive = true});
  final VoidCallback onOpenAgenda;
  final bool isActive;
  @override
  State<AutomaticLiveScreen> createState() => _AutomaticLiveScreenState();
}

class _AutomaticLiveScreenState extends State<AutomaticLiveScreen> with WidgetsBindingObserver {
  final AutomaticLiveService _service = AutomaticLiveService();
  List<ScheduledLiveEvent> _scheduled = <ScheduledLiveEvent>[];
  List<FutbolLibreEvent> _agendaEvents = <FutbolLibreEvent>[];
  AutoLiveSettings? _settings;
  Timer? _timer;
  bool _loading = true;
  String? _error;
  DateTime _updatedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh(force: true);
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && widget.isActive) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant AutomaticLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _refresh(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) _refresh(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool force = false}) async {
    if (_loading && !force) return;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final settings = await AutoLiveSettings.load();
      final events = await FutbolLibreAgendaStore.load();
      var scheduled = <ScheduledLiveEvent>[];
      if (settings.isConfigured && events.isNotEmpty) {
        scheduled = await _service.schedule(
          events: events, now: DateTime.now(), settings: settings, forceRefresh: force,
        );
      }
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _agendaEvents = events;
        _scheduled = scheduled;
        _loading = false;
        _updatedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString(); _updatedAt = DateTime.now(); });
    }
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _remaining(DateTime date) {
    final seconds = date.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return 'En curso';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return 'En $minutes min';
    return 'En ${minutes ~/ 60} h ${minutes % 60} min';
  }

  Future<void> _play(ScheduledLiveEvent event, ScheduledLiveSource source) async {
    if (!isDirectPlayableStream(source.url)) return;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => LivePlayerGridScreen(sources: <LivePlayerSource>[
        LivePlayerSource(title: '${event.event.title} · ${source.channelName}', url: source.url),
      ]),
    ));
    if (mounted) _refresh();
  }

  Future<void> _openMultiView() async {
    final sources = <LivePlayerSource>[];
    for (final item in _scheduled) {
      if (sources.length >= 4) break;
      if (item.sources.isEmpty) continue;
      final source = item.sources.first;
      if (!isDirectPlayableStream(source.url)) continue;
      sources.add(LivePlayerSource(
        title: '${item.event.title} · ${source.channelName}', url: source.url,
      ));
    }
    if (sources.isEmpty) return;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => LivePlayerGridScreen(sources: sources),
    ));
    if (mounted) _refresh();
  }

  Widget _notice(String title, String body, {IconData icon = Icons.info_outline_rounded}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _autoPanel, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _autoLine)),
      child: Column(children: <Widget>[
        Icon(icon, color: _autoCyan, size: 32),
        const SizedBox(height: 9),
        Text(title, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(body, textAlign: TextAlign.center,
          style: const TextStyle(color: _autoMuted, fontSize: 11, height: 1.5)),
      ]),
    );
  }

  Widget _eventCard(ScheduledLiveEvent item) {
    final event = item.event;
    final started = !DateTime.now().isBefore(event.startsAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _autoPanel, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: started ? _autoPink : _autoLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(event.competition.isEmpty ? event.sport.toUpperCase() : event.competition,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _autoMuted, fontSize: 10, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (started ? _autoPink : _autoGreen).withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: started ? _autoPink : _autoGreen)),
            child: Text(started ? 'EN VIVO' : 'PREPARADA',
              style: TextStyle(color: started ? _autoPink : _autoGreen,
                fontSize: 9, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Row(children: <Widget>[
          const Icon(Icons.schedule_rounded, color: _autoCyan, size: 15),
          const SizedBox(width: 5),
          Text(_time(event.startsAt), style: const TextStyle(color: _autoCyan, fontWeight: FontWeight.w900)),
          const SizedBox(width: 9),
          Text(_remaining(event.startsAt), style: const TextStyle(color: _autoMuted, fontSize: 10)),
          const Spacer(),
          Text('1 canal seleccionado', style: const TextStyle(color: _autoMuted, fontSize: 10)),
        ]),
        const SizedBox(height: 10),
        for (final source in item.sources)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(color: const Color(0xFF0B1B31),
              borderRadius: BorderRadius.circular(9), border: Border.all(color: _autoLine)),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.live_tv_rounded, color: _autoGreen),
              title: Text(source.channelName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              subtitle: Text(
                source.available
                    ? 'Señal comprobada · EPG: ${source.programmeTitle}'
                    : 'Fuente seleccionada · disponibilidad no confirmada · EPG: ${source.programmeTitle}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _autoMuted, fontSize: 9)),
              trailing: IconButton(
                tooltip: 'Reproducir con ExoPlayer',
                onPressed: () => _play(item, source),
                icon: const Icon(Icons.play_circle_fill_rounded, color: _autoCyan, size: 29),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = _settings?.isConfigured ?? false;
    return Scaffold(
      backgroundColor: _autoBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text('TRANSMISIONES EN VIVO',
          style: TextStyle(color: _autoCyan, fontSize: 14, fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(onPressed: _loading ? null : () => _refresh(force: true),
            tooltip: 'Actualizar transmisiones',
            icon: const Icon(Icons.refresh_rounded, color: _autoCyan)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(force: true),
        color: _autoCyan, backgroundColor: _autoPanel,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(13),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _autoPanel, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _autoLine)),
              child: const Row(children: <Widget>[
                Icon(Icons.auto_awesome_rounded, color: _autoGreen),
                SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text('PROGRAMACIÓN AUTOMÁTICA',
                    style: TextStyle(color: _autoGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Busca señales desde 10 minutos antes y las retira al terminar su EPG.',
                    style: TextStyle(color: _autoMuted, fontSize: 10, height: 1.4)),
                ])),
              ]),
            ),
            const SizedBox(height: 11),
            if (_loading && _scheduled.isEmpty)
              const Padding(padding: EdgeInsets.all(22),
                child: Center(child: CircularProgressIndicator(color: _autoCyan))),
            if (_error != null)
              _notice('No se pudo actualizar el catálogo', _error!, icon: Icons.cloud_off_rounded),
            if (!configured && !_loading)
              _notice('Falta configurar M3U y EPG',
                'Abre Ajustes de desarrollador y añade las direcciones de tu lista M3U y guía XMLTV de un proveedor autorizado. Las direcciones se guardan localmente en este teléfono.',
                icon: Icons.settings_suggest_rounded),
            if (_agendaEvents.isEmpty && !_loading) ...<Widget>[
              _notice('Agenda de Fútbol Libre pendiente',
                'Abre Agenda de hoy para que la APK lea los eventos visibles publicados por Fútbol Libre.',
                icon: Icons.event_busy_rounded),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onOpenAgenda,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('ABRIR AGENDA DE FÚTBOL LIBRE'),
                style: OutlinedButton.styleFrom(foregroundColor: _autoCyan,
                  side: const BorderSide(color: _autoCyan)),
              ),
            ],
            if (configured && _agendaEvents.isNotEmpty && _scheduled.isEmpty && !_loading && _error == null)
              _notice('Todavía no hay señales asociadas',
                'No se encontró una coincidencia suficiente entre el título del evento, la hora de la EPG y un canal de la lista. No se asignan canales al azar.',
                icon: Icons.search_off_rounded),
            if (_scheduled.isNotEmpty) ...<Widget>[
              Row(children: <Widget>[
                Expanded(child: Text('${_scheduled.length} eventos con señal asignada',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                if (_scheduled.length > 1)
                  FilledButton.icon(onPressed: _openMultiView,
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: Text(_scheduled.length > 4 ? 'MULTIVISTA · 4' : 'MULTIVISTA'),
                    style: FilledButton.styleFrom(backgroundColor: _autoPink,
                      foregroundColor: Colors.white, visualDensity: VisualDensity.compact)),
              ]),
              const SizedBox(height: 9),
              for (final item in _scheduled) _eventCard(item),
            ],
            const SizedBox(height: 10),
            Text('Actualizado ${_time(_updatedAt)} · se revisa cada 45 segundos mientras esta sección está abierta.',
              textAlign: TextAlign.center, style: const TextStyle(color: _autoMuted, fontSize: 9)),
            const SizedBox(height: 10),
            const Text('La calidad depende de las señales, del proveedor, de los derechos disponibles en tu región y de la conexión. La APK no puede garantizar que una fuente externa esté siempre activa.',
              textAlign: TextAlign.center, style: TextStyle(color: _autoMuted, fontSize: 9, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
