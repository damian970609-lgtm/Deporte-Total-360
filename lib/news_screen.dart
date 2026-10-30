import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

const Color _newsBg = Color(0xFF030814);
const Color _newsPanel = Color(0xFF071326);
const Color _newsLine = Color(0xFF123D65);
const Color _newsCyan = Color(0xFF00E5FF);
const Color _newsBlue = Color(0xFF087BFF);
const Color _newsPink = Color(0xFFFF28CF);
const Color _newsGreen = Color(0xFF39FF9C);
const Color _newsMuted = Color(0xFFA9BDD6);

class NewsSource {
  const NewsSource({
    required this.name,
    required this.category,
    required this.url,
  });

  final String name;
  final String category;
  final String url;
}

class NewsStory {
  const NewsStory({
    required this.title,
    required this.summary,
    required this.link,
    required this.source,
    required this.category,
    this.imageUrl,
    this.publishedAt,
  });

  final String title;
  final String summary;
  final String link;
  final String source;
  final String category;
  final String? imageUrl;
  final DateTime? publishedAt;
}

class NewsRepository {
  static const List<NewsSource> sources = <NewsSource>[
    NewsSource(
      name: 'AS • Fútbol',
      category: 'Fútbol',
      url:
          'https://feeds.as.com/mrss-s/pages/as/site/as.com/section/futbol/portada/',
    ),
    NewsSource(
      name: 'AS • Baloncesto',
      category: 'Baloncesto',
      url:
          'https://feeds.as.com/mrss-s/pages/as/site/as.com/section/baloncesto/portada/',
    ),
    NewsSource(
      name: 'AS • Tenis',
      category: 'Tenis',
      url:
          'https://feeds.as.com/mrss-s/pages/as/site/as.com/section/tenis/portada/',
    ),
    NewsSource(
      name: 'BBC Sport',
      category: 'Otros',
      url: 'https://feeds.bbci.co.uk/sport/rss.xml',
    ),
    NewsSource(
      name: 'BBC Sport • Fútbol',
      category: 'Fútbol',
      url: 'https://feeds.bbci.co.uk/sport/football/rss.xml',
    ),
    NewsSource(
      name: 'BBC Sport • Fórmula 1',
      category: 'Motor',
      url: 'https://feeds.bbci.co.uk/sport/formula1/rss.xml',
    ),
    NewsSource(
      name: 'Sky Sports',
      category: 'Otros',
      url: 'https://www.skysports.com/rss/12040',
    ),
    NewsSource(
      name: 'Sky Sports • Fútbol',
      category: 'Fútbol',
      url: 'https://www.skysports.com/rss/11095',
    ),
    NewsSource(
      name: 'The Guardian • Fútbol',
      category: 'Fútbol',
      url: 'https://www.theguardian.com/football/rss',
    ),
    NewsSource(
      name: 'The Guardian • Deportes',
      category: 'Otros',
      url: 'https://www.theguardian.com/sport/rss',
    ),
    NewsSource(
      name: 'Google News • Deportes',
      category: 'Otros',
      url:
          'https://news.google.com/rss/headlines/section/topic/SPORTS?hl=es-419&gl=US&ceid=US:es-419',
    ),
    NewsSource(
      name: 'Google News • Fútbol',
      category: 'Fútbol',
      url:
          'https://news.google.com/rss/search?q=futbol&hl=es-419&gl=US&ceid=US:es-419',
    ),
  ];

  static Future<List<NewsStory>> load() async {
    final results = await Future.wait(
      sources.map((source) async {
        try {
          return await _loadSource(source);
        } catch (_) {
          // Un RSS caído no debe impedir que carguen las demás noticias.
          return <NewsStory>[];
        }
      }),
    );

    final unique = <String, NewsStory>{};

    for (final group in results) {
      for (final story in group) {
        unique.putIfAbsent(story.link, () => story);
      }
    }

    final stories = unique.values.toList()
      ..sort((a, b) {
        final dateA =
            a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

    if (stories.isEmpty) {
      throw Exception(
        'No se pudo obtener noticias de las fuentes. '
        'Comprueba tu conexión e inténtalo de nuevo.',
      );
    }

    return stories;
  }

  static Future<List<NewsStory>> _loadSource(NewsSource source) async {
    final response = await http
        .get(
          Uri.parse(source.url),
          headers: const <String, String>{
            'User-Agent': 'DeporteTotal360/1.0 RSS Reader',
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.body);

    var entries = document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'item')
        .toList();

    if (entries.isEmpty) {
      entries = document.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'entry')
          .toList();
    }

    final stories = <NewsStory>[];

    for (final entry in entries) {
      final title = _childText(entry, 'title');
      final rawLink = _readLink(entry);
      final uri = Uri.tryParse(rawLink);

      if (title.isEmpty ||
          uri == null ||
          !uri.hasAuthority ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        continue;
      }

      final rawDescription = _childText(entry, 'description').isNotEmpty
          ? _childText(entry, 'description')
          : _childText(entry, 'summary').isNotEmpty
              ? _childText(entry, 'summary')
              : _childText(entry, 'encoded');

      final summary = _cleanText(rawDescription);
      final dateText = _childText(entry, 'pubDate').isNotEmpty
          ? _childText(entry, 'pubDate')
          : _childText(entry, 'published').isNotEmpty
              ? _childText(entry, 'published')
              : _childText(entry, 'updated');

      final sourceText = _childText(entry, 'source');
      final image = _readImage(entry, rawDescription);

      stories.add(
        NewsStory(
          title: _cleanText(title),
          summary: summary,
          link: uri.toString(),
          source: sourceText.isEmpty ? source.name : sourceText,
          category: source.category,
          imageUrl: image,
          publishedAt: _parseDate(dateText),
        ),
      );
    }

    return stories;
  }

  static String _childText(XmlElement parent, String name) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == name) {
        return child.innerText.trim();
      }
    }
    return '';
  }

  static String _readLink(XmlElement entry) {
    for (final child in entry.children.whereType<XmlElement>()) {
      if (child.name.local == 'link') {
        final textValue = child.innerText.trim();
        if (textValue.isNotEmpty) return textValue;

        final href = child.getAttribute('href');
        if (href != null && href.trim().isNotEmpty) return href.trim();
      }
    }
    return '';
  }

  static String? _readImage(XmlElement entry, String description) {
    for (final element in entry.descendants.whereType<XmlElement>()) {
      final tag = element.name.local.toLowerCase();

      if (tag == 'enclosure' ||
          tag == 'content' ||
          tag == 'thumbnail') {
        final candidate = element.getAttribute('url') ??
            element.getAttribute('href');

        if (candidate != null && _isWebImage(candidate)) {
          return candidate;
        }
      }
    }

    final match = RegExp(
      r"""<img[^>]+src=["']([^"']+)["']""",
      caseSensitive: false,
    ).firstMatch(description);

    final candidate = match?.group(1);
    if (candidate != null && _isWebImage(candidate)) {
      return candidate;
    }

    return null;
  }

  static bool _isWebImage(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  static String _cleanText(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;|&#160;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;

    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed;

    try {
      return HttpDate.parse(value.trim()).toUtc();
    } catch (_) {
      return null;
    }
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<NewsStory>> _future;
  String _category = 'Todos';
  String _query = '';

  static const List<String> _categories = <String>[
    'Todos',
    'Fútbol',
    'Baloncesto',
    'Tenis',
    'Motor',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _future = NewsRepository.load();
  }

  Future<void> _refresh() async {
    final future = NewsRepository.load();
    setState(() => _future = future);
    await future;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _newsBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'NOTICIAS DEPORTIVAS',
          style: TextStyle(
            color: _newsCyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar noticias',
            onPressed: () {
              _refresh().catchError((_) {});
            },
            icon: const Icon(Icons.refresh_rounded, color: _newsCyan),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _category;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = category),
                  selectedColor: _newsBlue,
                  backgroundColor: _newsPanel,
                  side: BorderSide(
                    color: selected ? _newsCyan : _newsLine,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : _newsMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar noticia, equipo o competición…',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _newsCyan,
                ),
                filled: true,
                fillColor: _newsPanel,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _newsLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _newsCyan),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<NewsStory>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _newsCyan),
                  );
                }

                if (snapshot.hasError && !snapshot.hasData) {
                  return _errorPanel(snapshot.error.toString());
                }

                final allStories = snapshot.data ?? <NewsStory>[];
                final query = _query.trim().toLowerCase();

                final stories = allStories.where((story) {
                  if (_category != 'Todos' &&
                      story.category != _category) {
                    return false;
                  }

                  if (query.isEmpty) return true;

                  final text =
                      '${story.title} ${story.summary} ${story.source}'
                          .toLowerCase();
                  return text.contains(query);
                }).toList();

                return RefreshIndicator(
                  color: _newsCyan,
                  backgroundColor: _newsPanel,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 3, 12, 22),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.bolt_rounded,
                              color: _newsPink,
                              size: 19,
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'ÚLTIMA HORA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${stories.length} noticias',
                              style: const TextStyle(
                                color: _newsMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'No hay noticias para este filtro. '
                            'Prueba otra categoría o búsqueda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _newsMuted),
                          ),
                        )
                      else
                        ...stories.map(
                          (story) => _NewsCard(
                            story: story,
                            dateLabel: _dateLabel(story.publishedAt),
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      NewsArticleReader(story: story),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Titulares y extractos procedentes de sus medios. '
                        'El artículo completo pertenece a su editor original.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _newsMuted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              color: _newsPink,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'NO SE PUDIERON CARGAR LAS NOTICIAS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _newsMuted, fontSize: 11),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                _refresh().catchError((_) {});
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('VOLVER A INTENTAR'),
              style: FilledButton.styleFrom(
                backgroundColor: _newsBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.story,
    required this.dateLabel,
    required this.onTap,
  });

  final NewsStory story;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _newsPanel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: _newsLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (story.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    story.imageUrl!,
                    width: 102,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  ),
                )
              else
                _imagePlaceholder(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      story.source.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _newsCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      story.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (story.summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        story.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _newsMuted,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      dateLabel.isEmpty ? story.category : dateLabel,
                      style: const TextStyle(
                        color: _newsGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _newsMuted,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 102,
      height: 92,
      decoration: BoxDecoration(
        color: _newsBlue.withAlpha(35),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _newsLine),
      ),
      child: const Icon(
        Icons.sports_soccer_rounded,
        color: _newsCyan,
        size: 31,
      ),
    );
  }
}

class NewsArticleReader extends StatefulWidget {
  const NewsArticleReader({super.key, required this.story});

  final NewsStory story;

  @override
  State<NewsArticleReader> createState() => _NewsArticleReaderState();
}

class _NewsArticleReaderState extends State<NewsArticleReader> {
  InAppWebViewController? _controller;
  bool _loading = true;
  bool _allowPop = false;
  bool _handlingBack = false;
  double _progress = 0;

  Future<void> _back() async {
    if (_handlingBack) return;
    _handlingBack = true;

    try {
      final controller = _controller;
      if (controller != null && await controller.canGoBack()) {
        await controller.goBack();
        return;
      }

      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    } finally {
      _handlingBack = false;
    }
  }

  Future<bool> _newWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }

    await controller.loadUrl(urlRequest: action.request);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _newsBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF020B19),
          leading: IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded, color: _newsCyan),
          ),
          title: Text(
            widget.story.source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _newsCyan,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recargar noticia',
              onPressed: () => _controller?.reload(),
              icon: const Icon(Icons.refresh_rounded, color: _newsCyan),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            if (_loading)
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2,
                backgroundColor: _newsPanel,
                color: _newsCyan,
              ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.story.link),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: true,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  safeBrowsingEnabled: true,
                  allowFileAccess: false,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadStart: (controller, url) {
                  if (!mounted) return;
                  setState(() {
                    _loading = true;
                    _progress = 0;
                  });
                },
                onProgressChanged: (controller, progress) {
                  if (!mounted) return;
                  setState(() {
                    _progress = progress / 100;
                    _loading = progress < 100;
                  });
                },
                onLoadStop: (controller, url) {
                  if (!mounted) return;
                  setState(() {
                    _loading = false;
                    _progress = 1;
                  });
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final uri = action.request.url;
                  if (uri == null) return NavigationActionPolicy.CANCEL;

                  if (uri.scheme == 'https' || uri.scheme == 'http') {
                    return NavigationActionPolicy.ALLOW;
                  }
                  return NavigationActionPolicy.CANCEL;
                },
                onCreateWindow: _newWindow,
                onReceivedError: (controller, request, error) {
                  if (!(request.isForMainFrame ?? true) || !mounted) return;
                  setState(() => _loading = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}