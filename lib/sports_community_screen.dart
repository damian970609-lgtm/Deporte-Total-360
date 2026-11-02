import 'package:flutter/material.dart';

import 'news_screen.dart';
import 'notification_service.dart';

const Color _communityBg = Color(0xFF030814);
const Color _communityPanel = Color(0xFF071326);
const Color _communityLine = Color(0xFF123D65);
const Color _communityCyan = Color(0xFF00E5FF);
const Color _communityPink = Color(0xFFFF28CF);
const Color _communityGreen = Color(0xFF39FF9C);
const Color _communityMuted = Color(0xFFA9BDD6);

class SportsFeedScreen extends StatefulWidget {
  const SportsFeedScreen({
    super.key,
    required this.onOpenLive,
    required this.onOpenAgenda,
    required this.onOpenNews,
    required this.onOpenSummaries,
    required this.onOpenChat,
  });

  final VoidCallback onOpenLive;
  final VoidCallback onOpenAgenda;
  final VoidCallback onOpenNews;
  final VoidCallback onOpenSummaries;
  final VoidCallback onOpenChat;

  @override
  State<SportsFeedScreen> createState() => _SportsFeedScreenState();
}

class _SportsFeedScreenState extends State<SportsFeedScreen> {
  late Future<List<NewsStory>> _future;

  @override
  void initState() {
    super.initState();
    _future = NewsRepository.load();
  }

  Future<void> _refresh() async {
    final next = NewsRepository.load();
    setState(() => _future = next);
    await next;
  }

  Widget _shortcut(String label, IconData icon, Color color, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: _communityPanel,
      side: BorderSide(color: color.withAlpha(150)),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _communityBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('FEED DEPORTIVO', style: TextStyle(
              color: _communityCyan, fontSize: 14, fontWeight: FontWeight.w900,
            )),
            Text('DEPORTE TOTAL 360°', style: TextStyle(
              color: _communityMuted, fontSize: 9,
            )),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar feed',
            onPressed: () => _refresh().catchError((_) {}),
            icon: const Icon(Icons.refresh_rounded, color: _communityCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              children: <Widget>[
                _shortcut('En vivo', Icons.live_tv_rounded, _communityPink, widget.onOpenLive),
                _shortcut('Partidos', Icons.calendar_month_rounded, _communityGreen, widget.onOpenAgenda),
                _shortcut('Noticias', Icons.article_rounded, _communityCyan, widget.onOpenNews),
                _shortcut('Resúmenes', Icons.play_circle_rounded, _communityPink, widget.onOpenSummaries),
                _shortcut('Chat', Icons.forum_rounded, _communityGreen, widget.onOpenChat),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<NewsStory>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(22),
                    children: const <Widget>[
                      SizedBox(height: 70),
                      Center(child: CircularProgressIndicator(color: _communityCyan)),
                      SizedBox(height: 14),
                      Center(child: Text('Cargando publicaciones deportivas…',
                        style: TextStyle(color: _communityMuted))),
                    ],
                  );
                }
                if (snapshot.hasError && !snapshot.hasData) {
                  return _emptyOrError('No se pudo actualizar el feed deportivo.',
                    snapshot.error.toString());
                }
                final stories = snapshot.data ?? <NewsStory>[];
                if (stories.isEmpty) {
                  return _emptyOrError('Todavía no hay publicaciones disponibles.',
                    'El feed utiliza las fuentes RSS deportivas ya configuradas. Puedes entrar a las otras secciones con los accesos superiores.');
                }
                return RefreshIndicator(
                  color: _communityCyan,
                  backgroundColor: _communityPanel,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
                    itemCount: stories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(2, 6, 2, 12),
                          child: Text('PUBLICACIONES DE FUENTES DEPORTIVAS',
                            style: TextStyle(color: _communityMuted, fontSize: 10,
                              fontWeight: FontWeight.w800)),
                        );
                      }
                      final story = stories[index - 1];
                      return Card(
                        color: _communityPanel,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _communityLine),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => NewsArticleReader(story: story),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(13),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    const Icon(Icons.public_rounded,
                                      color: _communityGreen, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('${story.source} · ${story.category}',
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _communityGreen,
                                          fontSize: 10, fontWeight: FontWeight.w800)),
                                    ),
                                    Text(_date(story.publishedAt),
                                      style: const TextStyle(color: _communityMuted, fontSize: 9)),
                                  ],
                                ),
                                if (story.imageUrl != null) ...<Widget>[
                                  const SizedBox(height: 9),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.network(
                                      story.imageUrl!, width: double.infinity, height: 155,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 9),
                                Text(story.title, style: const TextStyle(
                                  color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w900, height: 1.3,
                                )),
                                if (story.summary.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 7),
                                  Text(story.summary, maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _communityMuted,
                                      fontSize: 12, height: 1.4)),
                                ],
                                const SizedBox(height: 10),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    Text('LEER PUBLICACIÓN',
                                      style: TextStyle(color: _communityCyan,
                                        fontSize: 10, fontWeight: FontWeight.w900)),
                                    SizedBox(width: 5),
                                    Icon(Icons.arrow_forward_rounded,
                                      size: 15, color: _communityCyan),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyOrError(String title, String detail) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 35),
        const Icon(Icons.dynamic_feed_rounded, color: _communityCyan, size: 48),
        const SizedBox(height: 13),
        Text(title, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center,
          style: const TextStyle(color: _communityMuted, fontSize: 11, height: 1.45)),
        const SizedBox(height: 14),
        Center(child: OutlinedButton.icon(
          onPressed: () => _refresh().catchError((_) {}),
          icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar'),
        )),
      ],
    );
  }
}

class SportsNotificationsScreen extends StatefulWidget {
  const SportsNotificationsScreen({
    super.key,
    required this.onOpenAgenda,
    required this.onOpenLive,
  });

  final VoidCallback onOpenAgenda;
  final VoidCallback onOpenLive;

  @override
  State<SportsNotificationsScreen> createState() => _SportsNotificationsScreenState();
}

class _SportsNotificationsScreenState extends State<SportsNotificationsScreen> {
  late Future<List<SportsAppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = NotificationService.loadHistory();
  }

  Future<void> _refresh() async {
    final next = NotificationService.loadHistory();
    setState(() => _future = next);
    await next;
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _communityPanel,
        title: const Text('Borrar notificaciones', style: TextStyle(color: Colors.white)),
        content: const Text('Se eliminará el historial guardado en este teléfono.',
          style: TextStyle(color: _communityMuted)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await NotificationService.clearHistory();
    if (mounted) await _refresh();
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  IconData _icon(String type) {
    switch (type) {
      case 'score': return Icons.sports_score_rounded;
      case 'reminder': return Icons.alarm_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _communityBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text('NOTIFICACIONES',
          style: TextStyle(color: _communityCyan, fontSize: 14, fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(tooltip: 'Actualizar',
            onPressed: () => _refresh().catchError((_) {}),
            icon: const Icon(Icons.refresh_rounded, color: _communityCyan)),
          IconButton(tooltip: 'Borrar historial', onPressed: _clear,
            icon: const Icon(Icons.delete_outline_rounded, color: _communityPink)),
        ],
      ),
      body: FutureBuilder<List<SportsAppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _communityCyan));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Text('No se pudo leer el historial: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _communityMuted)),
              ),
            );
          }
          final notifications = snapshot.data ?? <SportsAppNotification>[];
          if (notifications.isEmpty) {
            return RefreshIndicator(
              color: _communityCyan,
              backgroundColor: _communityPanel,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  const SizedBox(height: 45),
                  const Icon(Icons.notifications_none_rounded,
                    color: _communityCyan, size: 54),
                  const SizedBox(height: 14),
                  const Text('Todavía no tienes notificaciones',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text(
                    'Aquí aparecerán los recordatorios de partidos y las actualizaciones de marcador que genere Deporte Total 360°.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _communityMuted, fontSize: 12, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Center(child: OutlinedButton.icon(
                    onPressed: widget.onOpenAgenda,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Ver agenda deportiva'),
                  )),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: _communityCyan,
            backgroundColor: _communityPanel,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  color: _communityPanel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _communityLine),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _communityCyan.withAlpha(25),
                      child: Icon(_icon(item.type), color: _communityCyan),
                    ),
                    title: Text(item.title, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.body, style: const TextStyle(color: _communityMuted, height: 1.35)),
                          const SizedBox(height: 5),
                          Text(_date(item.createdAt), style: const TextStyle(
                            color: _communityGreen, fontSize: 10)),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: _communityMuted),
                    onTap: item.type == 'score' ? widget.onOpenLive : widget.onOpenAgenda,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
