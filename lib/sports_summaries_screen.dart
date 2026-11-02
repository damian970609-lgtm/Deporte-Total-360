import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'app_i18n.dart';

const Color _summaryBg = Color(0xFF030814);
const Color _summaryPanel = Color(0xFF071326);
const Color _summaryLine = Color(0xFF123D65);
const Color _summaryCyan = Color(0xFF00E5FF);
const Color _summaryBlue = Color(0xFF087BFF);
const Color _summaryPink = Color(0xFFFF28CF);
const Color _summaryMuted = Color(0xFFA9BDD6);

class _SummaryChannel {
  const _SummaryChannel({
    required this.name,
    required this.category,
    required this.channelId,
  });

  final String name;
  final String category;
  final String channelId;

  Uri get feedUri => Uri.https(
        'www.youtube.com',
        '/feeds/videos.xml',
        <String, String>{'channel_id': channelId},
      );
}

class _SportsVideo {
  const _SportsVideo({
    required this.id,
    required this.title,
    required this.channel,
    required this.category,
    required this.publishedAt,
    this.thumbnail,
  });

  final String id;
  final String title;
  final String channel;
  final String category;
  final DateTime? publishedAt;
  final String? thumbnail;

  String get embedUrl =>
      'https://www.youtube-nocookie.com/embed/' +
      id +
      '?autoplay=1&controls=1&playsinline=1&rel=0';
}

/// Últimos vídeos y resúmenes de canales deportivos oficiales de YouTube.
class SportsSummariesScreen extends StatefulWidget {
  const SportsSummariesScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<SportsSummariesScreen> createState() => _SportsSummariesScreenState();
}

class _SportsSummariesScreenState extends State<SportsSummariesScreen> {
  static const List<_SummaryChannel> _channels = <_SummaryChannel>[
    _SummaryChannel(
      name: 'FIFA',
      category: 'Fútbol',
      channelId: 'UCpcTrCXblq78GZrTUTLWeBw',
    ),
    _SummaryChannel(
      name: 'UEFA',
      category: 'Fútbol',
      channelId: 'UCyGa1YEx9ST66rYrJTGIKOw',
    ),
    _SummaryChannel(
      name: 'NBA',
      category: 'Baloncesto',
      channelId: 'UCWJ2lWNubArHWmf3FIHbfcQ',
    ),
  ];

  static const List<String> _filters = <String>[
    'Todos',
    'Fútbol',
    'Baloncesto',
  ];

  List<_SportsVideo> _videos = <_SportsVideo>[];
  bool _loading = false;
  String? _error;
  String _filter = 'Todos';
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _loadVideos();
  }

  @override
  void didUpdateWidget(covariant SportsSummariesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && _videos.isEmpty) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final errors = <String>[];
    final groups = await Future.wait(
      _channels.map((channel) async {
        try {
          return await _loadChannel(channel);
        } catch (error) {
          errors.add(channel.name + ': ' + error.toString());
          return <_SportsVideo>[];
        }
      }),
    );

    final unique = <String, _SportsVideo>{};
    for (final group in groups) {
      for (final video in group) {
        unique.putIfAbsent(video.id, () => video);
      }
    }

    final videos = unique.values.toList()
      ..sort((a, b) {
        final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    if (!mounted) return;
    setState(() {
      _videos = videos;
      _loading = false;
      _lastUpdated = DateTime.now();
      if (videos.isEmpty) {
        _error = errors.isEmpty
            ? appText(
                'Los canales no publicaron vídeos disponibles.',
                'The channels have no available videos.',
                'Os canais não publicaram vídeos disponíveis.',
                'Les chaînes n’ont pas publié de vídeos disponíveis.',
              )
            : appText(
                'No se pudo leer ningún canal. Comprueba Internet y vuelve a intentar.',
                'No channel could be read. Check your connection and retry.',
                'Não foi possível ler nenhum canal. Verifique a conexão e tente novamente.',
                'Impossible de lire les chaînes. Vérifiez la connexion et réessayez.',
              ) +
                '\n' +
                errors.take(2).join('\n');
      }
    });
  }

  Future<List<_SportsVideo>> _loadChannel(_SummaryChannel channel) async {
    final response = await http
        .get(
          channel.feedUri,
          headers: const <String, String>{
            'User-Agent': 'DeporteTotal360/1.0 (YouTube RSS reader)',
            'Accept': 'application/atom+xml, application/xml, text/xml, */*',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ' + response.statusCode.toString());
    }

    final document = XmlDocument.parse(response.body);
    final entries = document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'entry');

    final videos = <_SportsVideo>[];
    for (final entry in entries) {
      final id = _entryValue(entry, 'videoId');
      final title = _entryValue(entry, 'title');
      if (id.isEmpty || title.isEmpty) continue;

      final published = _entryValue(entry, 'published');
      final dateText =
          published.isNotEmpty ? published : _entryValue(entry, 'updated');
      videos.add(
        _SportsVideo(
          id: id,
          title: title,
          channel: channel.name,
          category: channel.category,
          publishedAt: DateTime.tryParse(dateText)?.toLocal(),
          thumbnail: _httpsUrl(_entryAttribute(entry, 'thumbnail', 'url')),
        ),
      );
    }

    return videos;
  }

  String _entryValue(XmlElement entry, String name) {
    for (final element in entry.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) return element.innerText.trim();
    }
    return '';
  }

  String _entryAttribute(XmlElement entry, String name, String attribute) {
    for (final element in entry.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) {
        return element.getAttribute(attribute) ?? '';
      }
    }
    return '';
  }

  String? _httpsUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri.toString();
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return day + '/' + month + ' • ' + hour + ':' + minute;
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos
        .where((video) => _filter == 'Todos' || video.category == _filter)
        .take(40)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: _summaryBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: Text(
          appText('RESÚMENES DEPORTIVOS', 'SPORTS HIGHLIGHTS',
              'RESUMOS ESPORTIVOS', 'RÉSUMÉS SPORTIFS'),
          style: const TextStyle(
            color: _summaryCyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: appText('Actualizar resúmenes', 'Refresh highlights',
                'Atualizar resumos', 'Actualiser les résumés'),
            onPressed: _loading ? null : _loadVideos,
            icon: const Icon(Icons.refresh_rounded, color: _summaryCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = _filters[index];
                final selected = value == _filter;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = value),
                  selectedColor: _summaryBlue,
                  backgroundColor: _summaryPanel,
                  side: BorderSide(
                    color: selected ? _summaryCyan : _summaryLine,
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  appText(
                    'Actualizado ' +
                        _dateLabel(_lastUpdated) +
                        ' · vídeos recientes de canales oficiales',
                    'Updated ' +
                        _dateLabel(_lastUpdated) +
                        ' · recent videos from official channels',
                    'Atualizado ' +
                        _dateLabel(_lastUpdated) +
                        ' · vídeos recentes de canais oficiais',
                    'Mis à jour ' +
                        _dateLabel(_lastUpdated) +
                        ' · vidéos récentes de chaînes officielles',
                  ),
                  style: const TextStyle(color: _summaryMuted, fontSize: 9),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _summaryCyan),
                  )
                : _error != null
                    ? _errorPanel()
                    : videos.isEmpty
                        ? Center(
                            child: Text(
                              appText('No hay resúmenes para este deporte.',
                                  'No highlights for this sport.',
                                  'Não há resumos para este esporte.',
                                  'Aucun résumé pour ce sport.'),
                              style: const TextStyle(color: _summaryMuted),
                            ),
                          )
                        : RefreshIndicator(
                            color: _summaryCyan,
                            backgroundColor: _summaryPanel,
                            onRefresh: _loadVideos,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(12, 4, 12, 22),
                              itemCount: videos.length,
                              itemBuilder: (context, index) {
                                final video = videos[index];
                                return Card(
                                  color: _summaryPanel,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    side: const BorderSide(
                                        color: _summaryLine),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              _SummaryPlayerScreen(video: video),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: <Widget>[
                                              if (video.thumbnail != null)
                                                Image.network(
                                                  video.thumbnail!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          _thumbnailFallback(),
                                                )
                                              else
                                                _thumbnailFallback(),
                                              Align(
                                                alignment: Alignment.center,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(13),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withAlpha(170),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: _summaryCyan,
                                                      width: 1.4,
                                                    ),
                                                    boxShadow: <BoxShadow>[
                                                      BoxShadow(
                                                        color: _summaryCyan
                                                            .withAlpha(55),
                                                        blurRadius: 15,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: 34,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 11, 12, 13),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                video.channel.toUpperCase() +
                                                    '  •  ' +
                                                    video.category.toUpperCase(),
                                                style: const TextStyle(
                                                  color: _summaryCyan,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                video.title,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.3,
                                                ),
                                              ),
                                              const SizedBox(height: 7),
                                              Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Text(
                                                      _dateLabel(
                                                          video.publishedAt),
                                                      style: const TextStyle(
                                                        color: _summaryMuted,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.play_circle_outline,
                                                    color: _summaryPink,
                                                    size: 17,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    appText(
                                                        'VER EN LA APP',
                                                        'WATCH IN APP',
                                                        'VER NO APP',
                                                        'REGARDER DANS L’APP'),
                                                    style: const TextStyle(
                                                      color: _summaryPink,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text(
              'Vídeos públicos insertados desde sus canales originales. '
              'La disponibilidad depende del permiso de inserción y de la región.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _summaryMuted,
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      color: _summaryBlue.withAlpha(30),
      child: const Center(
        child: Icon(Icons.sports_soccer_rounded,
            color: _summaryCyan, size: 48),
      ),
    );
  }

  Widget _errorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.wifi_off_rounded,
                color: _summaryPink, size: 42),
            const SizedBox(height: 12),
            Text(
              _error ??
                  appText('No hay conexión.', 'No connection.',
                      'Sem conexão.', 'Aucune connexion.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadVideos,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(appText('VOLVER A INTENTAR', 'TRY AGAIN',
                  'TENTAR NOVAMENTE', 'RÉESSAYER')),
              style: FilledButton.styleFrom(
                backgroundColor: _summaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPlayerScreen extends StatefulWidget {
  const _SummaryPlayerScreen({required this.video});

  final _SportsVideo video;

  @override
  State<_SummaryPlayerScreen> createState() => _SummaryPlayerScreenState();
}

class _SummaryPlayerScreenState extends State<_SummaryPlayerScreen> {
  bool _loading = true;
  String? _error;
  InAppWebViewController? _controller;

  static const String _playerBaseUrl =
      'https://deporte-total-360-api.damian970609.workers.dev/';

  String get _playerHtml {
    final id = widget.video.id;
    if (id.isEmpty || id.contains(RegExp(r'[^A-Za-z0-9_-]'))) {
      return '<!doctype html><html><body>Video ID no válido</body></html>';
    }
    return '''
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta name="referrer" content="origin">
<style>
html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}
.player{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}
iframe{width:100%;height:100%;border:0;background:#000}
</style>
</head>
<body>
<div class="player">
<iframe
  src="https://www.youtube-nocookie.com/embed/$id?autoplay=1&controls=1&playsinline=1&rel=0"
  title="Resumen deportivo"
  referrerpolicy="origin"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
  allowfullscreen>
</iframe>
</div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _summaryBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: Text(
          widget.video.channel,
          style: const TextStyle(
            color: _summaryCyan,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recargar vídeo',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh_rounded, color: _summaryCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: _summaryCyan,
              backgroundColor: _summaryPanel,
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.error_outline_rounded,
                              color: _summaryPink, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _error = null;
                                _loading = true;
                              });
                              _controller?.reload();
                            },
                            child: Text(appText('Reintentar', 'Retry',
                                'Tentar novamente', 'Réessayer')),
                          ),
                        ],
                      ),
                    ),
                  )
                : InAppWebView(
                    // baseUrl HTTPS suministra el Referer requerido por YouTube
                    // al cargar el iframe dentro de esta WebView.
                    initialData: InAppWebViewInitialData(
                      data: _playerHtml,
                      baseUrl: WebUri(_playerBaseUrl),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: false,
                      iframeAllowFullscreen: true,
                      isElementFullscreenEnabled: true,
                      supportMultipleWindows: false,
                      safeBrowsingEnabled: true,
                      useShouldOverrideUrlLoading: true,
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (!mounted) return;
                      setState(() => _loading = progress < 100);
                    },
                    onLoadStop: (controller, url) {
                      if (!mounted) return;
                      setState(() => _loading = false);
                    },
                    shouldOverrideUrlLoading: (controller, action) async {
                      if (!(action.isForMainFrame ?? true)) {
                        return NavigationActionPolicy.ALLOW;
                      }
                      final uri = action.request.url;
                      if (uri == null) return NavigationActionPolicy.CANCEL;
                      final host = uri.host.toLowerCase();
                      if (host == 'youtube-nocookie.com' ||
                          host == 'www.youtube-nocookie.com') {
                        return NavigationActionPolicy.ALLOW;
                      }
                      if (host == 'youtube.com' ||
                          host.endsWith('.youtube.com') ||
                          host == 'youtu.be') {
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.CANCEL;
                    },
                    onCreateWindow: (controller, action) async => false,
                    onReceivedError: (controller, request, error) {
                      if (!(request.isForMainFrame ?? true) || !mounted) {
                        return;
                      }
                      setState(() {
                        _loading = false;
                        _error = appText(
                          'No se pudo cargar el vídeo incrustado. Puede estar restringido por su canal o región.',
                          'The embedded video could not be loaded. It may be restricted by its channel or region.',
                          'Não foi possível carregar o vídeo incorporado. Ele pode estar restrito pelo canal ou região.',
                          'La vidéo intégrée n’a pas pu être chargée. Elle peut être restreinte par la chaîne ou la région.',
                        );
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
