import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'web_agenda_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeporteTotal360App());
}

const bg = Color(0xFF030814);
const panel = Color(0xFF09172B);
const cyan = Color(0xFF00E5FF);
const pink = Color(0xFFFF28CF);
const green = Color(0xFF39FF9C);
const yellow = Color(0xFFFFD600);
const muted = Color(0xFFB4C4D9);

// La app reproduce HLS. PRISM debe publicar en SSH101 y el canal debe estar EN VIVO.
// Usa la URL que aparece en el panel SSH101 si el servidor asignado es distinto.
const streamUrls = <String>[
  'https://live21.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8',
  'https://live20.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8',
];
const agendaUrl = 'https://futbol-libre.cam/';
const fallbackAgendaUrl = 'https://www.espn.com/soccer/scoreboard';
const telegramUrl = 'https://t.me/'; // Cámbialo por el enlace real del canal.

class DeporteTotal360App extends StatelessWidget {
  const DeporteTotal360App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DEPORTE TOTAL 360°',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: cyan,
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: bg,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        home: const HomeScreen(),
      );
}

void showWeb(
  BuildContext context, {
  String url = agendaUrl,
  String title = 'AGENDA DEPORTIVA',
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          WebAgendaScreen(initialUrl: url, pageTitle: title),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 65,
          titleSpacing: 15,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_soccer,
                  color: cyan,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DEPORTE TOTAL 360°',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'TU PASIÓN, EN TODAS PARTES',
                    style: TextStyle(
                      color: muted,
                      fontSize: 9,
                      letterSpacing: .6,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: 'Telegram',
              onPressed: () => showWeb(
                context,
                url: telegramUrl,
                title: 'TELEGRAM',
              ),
              icon: const Icon(Icons.send_rounded, color: cyan),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF07152B), bg, Color(0xFF090B1A)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 28),
              children: [
                const _HeroPanel(),
                const SizedBox(height: 24),
                const _Heading('TU MUNDO DEPORTIVO', cyan),
                const SizedBox(height: 12),
                const _SportsRow(),
                const SizedBox(height: 24),
                const _Heading('AGENDA DE PARTIDOS', green),
                const SizedBox(height: 12),
                _AgendaCard(onTap: () => showWeb(context)),
                const SizedBox(height: 23),
                const _Heading('TRANSMISIONES', pink),
                const SizedBox(height: 12),
                _LiveCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LiveScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 23),
                const _Heading('ACCESO RÁPIDO', cyan),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, box) {
                  final cols = box.maxWidth >= 520 ? 3 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: cols == 3 ? 1.2 : 1.3,
                    children: [
                      _QuickCard(
                        icon: Icons.sports_soccer_rounded,
                        title: 'FÚTBOL',
                        subtitle: 'AGENDA Y MARCADORES',
                        color: cyan,
                        onTap: () => showWeb(context),
                      ),
                      _QuickCard(
                        icon: Icons.send_rounded,
                        title: 'TELEGRAM',
                        subtitle: 'CANAL DE LA COMUNIDAD',
                        color: const Color(0xFF28A8E9),
                        onTap: () => showWeb(
                          context,
                          url: telegramUrl,
                          title: 'TELEGRAM',
                        ),
                      ),
                      _QuickCard(
                        icon: Icons.favorite_rounded,
                        title: 'DONACIONES',
                        subtitle: 'APOYA EL PROYECTO',
                        color: yellow,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DonationsScreen(),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 25),
                const Text(
                  'DEPORTE TOTAL 360°  •  EL DEPORTE NOS UNE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF102F55),
              Color(0xFF171238),
              Color(0xFF071C2D),
            ],
          ),
          border: Border.all(color: cyan.withValues(alpha: .65)),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: .08),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(),
                SizedBox(height: 11),
                Text(
                  'EL DEPORTE\nSE VIVE AQUÍ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.03,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Partidos, agenda y transmisiones en un solo lugar.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .2),
              shape: BoxShape.circle,
              border: Border.all(color: pink, width: 1.4),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.emoji_events_rounded,
                  color: yellow,
                  size: 43,
                ),
              ),
            ),
          ),
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: green.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: green.withValues(alpha: .8)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: green, size: 14),
            SizedBox(width: 5),
            Text(
              'TODO EL DEPORTE',
              style: TextStyle(
                color: green,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.color);
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
      ]);
}

class _SportsRow extends StatelessWidget {
  const _SportsRow();

  @override
  Widget build(BuildContext context) {
    const sports = <({IconData icon, String title, Color color})>[
      (
        icon: Icons.sports_soccer_rounded,
        title: 'FÚTBOL',
        color: cyan
      ),
      (
        icon: Icons.sports_basketball_rounded,
        title: 'BÁSQUET',
        color: yellow
      ),
      (
        icon: Icons.sports_tennis_rounded,
        title: 'TENIS',
        color: green
      ),
      (
        icon: Icons.sports_baseball_rounded,
        title: 'BÉISBOL',
        color: pink
      ),
      (
        icon: Icons.sports_volleyball_rounded,
        title: 'VOLEY',
        color: Color(0xFF3987FF)
      ),
    ];

    return SizedBox(
      height: 77,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = sports[i];
          return Container(
            width: 77,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: s.color.withValues(alpha: .55),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icon, color: s.color, size: 26),
                const SizedBox(height: 5),
                Text(
                  s.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: green.withValues(alpha: .65)),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: green.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: green,
                size: 27,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROGRAMACIÓN Y RESULTADOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Consulta la agenda deportiva actualizada.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.sports_soccer_rounded),
              label: const Text('ABRIR AGENDA DE PARTIDOS'),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: bg,
              ),
            ),
          ),
        ]),
      );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pink.withValues(alpha: .7)),
        ),
        child: Row(children: [
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: pink.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: pink,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.circle, color: pink, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'CANAL EN VIVO',
                    style: TextStyle(
                      color: pink,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ]),
                SizedBox(height: 5),
                Text(
                  'Señal de DEPORTE TOTAL 360°',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'HLS · SSH101',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onTap,
            tooltip: 'Ver transmisión',
            style: IconButton.styleFrom(
              backgroundColor: pink,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 29),
          ),
        ]),
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .6)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  String? _errorMessage;
  String? _activeUrl;

  @override
  void initState() {
    super.initState();
    _startPlayer();
  }

  Future<void> _startPlayer() async {
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      previous.removeListener(_checkPlayerError);
      await previous.dispose();
    }
    if (!mounted) return;

    setState(() {
      _loading = true;
      _failed = false;
      _errorMessage = null;
      _activeUrl = null;
    });

    String lastError = 'SSH101 no devolvió una señal reproducible.';

    for (final url in streamUrls) {
      final candidate =
          VideoPlayerController.networkUrl(Uri.parse(url));

      try {
        await candidate
            .initialize()
            .timeout(const Duration(seconds: 14));

        if (!mounted) {
          await candidate.dispose();
          return;
        }

        _controller = candidate;
        _activeUrl = url;
        candidate.addListener(_checkPlayerError);
        await candidate.setLooping(false);
        await candidate.play();

        if (!mounted) return;

        setState(() {
          _loading = false;
          _failed = false;
        });
        return;
      } catch (error) {
        lastError = '$url\n$error';
        if (_controller == candidate) _controller = null;
        candidate.removeListener(_checkPlayerError);
        await candidate.dispose();
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
        _errorMessage = lastError;
      });
    }
  }

  void _checkPlayerError() {
    final c = _controller;
    if (!mounted || c == null || !c.value.hasError || _failed) {
      return;
    }

    setState(() {
      _loading = false;
      _failed = true;
      _errorMessage =
          c.value.errorDescription ?? 'Error del reproductor HLS.';
    });
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_checkPlayerError);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized && !_failed;
    final ratio = c != null &&
            c.value.isInitialized &&
            !_failed &&
            c.value.aspectRatio > 0
        ? c.value.aspectRatio
        : 16 / 9;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TRANSMISIONES EN VIVO',
          style: TextStyle(
            color: cyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
        children: [
          const _Heading('CANAL DE DEPORTE TOTAL 360°', pink),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: AspectRatio(
              aspectRatio: ratio,
              child: ColoredBox(
                color: Colors.black,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: cyan),
                      )
                    : !ready
                        ? OfflinePanel(message: _errorMessage)
                        : VideoPlayer(c!),
              ),
            ),
          ),
          if (ready && c != null) ...[
            const SizedBox(height: 10),
            VideoProgressIndicator(
              c,
              allowScrubbing: false,
              colors: const VideoProgressColors(
                playedColor: pink,
                bufferedColor: muted,
                backgroundColor: panel,
              ),
            ),
            Row(children: [
              IconButton(
                tooltip: c.value.isPlaying ? 'Pausar' : 'Reproducir',
                onPressed: () async {
                  if (c.value.isPlaying) {
                    await c.pause();
                  } else {
                    await c.play();
                  }
                  if (mounted) setState(() {});
                },
                icon: Icon(
                  c.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: cyan,
                  size: 30,
                ),
              ),
              const Expanded(
                child: Text(
                  'TRANSMISIÓN HLS',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Recargar señal',
                onPressed: _startPlayer,
                icon: const Icon(Icons.refresh_rounded, color: green),
              ),
            ]),
            if (_activeUrl != null)
              Text(
                'Fuente: $_activeUrl',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startPlayer,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('RECARGAR SEÑAL'),
              ),
            ),
          ],
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: cyan.withValues(alpha: .35)),
            ),
            child: const Text(
              'PRISM publica al servidor RTMP de SSH101. La APK reproduce la salida HLS .m3u8. Para que haya imagen, el canal debe estar transmitiendo y la URL HLS tiene que coincidir exactamente con la que muestra tu panel SSH101.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          _AgendaCard(onTap: () => showWeb(context)),
        ],
      ),
    );
  }
}

class OfflinePanel extends StatelessWidget {
  const OfflinePanel({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.portable_wifi_off_rounded,
                color: pink,
                size: 42,
              ),
              const SizedBox(height: 9),
              const Text(
                'SEÑAL NO DISPONIBLE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cyan,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Verifica tu conexión, el estado EN VIVO del canal y la URL HLS en SSH101.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('DONACIONES')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded, color: pink, size: 70),
                SizedBox(height: 17),
                Text(
                  'APOYA EL PROYECTO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cyan,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Gracias por apoyar a DEPORTE TOTAL 360°. Próximamente añadiremos opciones de donación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
}