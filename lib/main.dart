import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'web_agenda_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeporteTotal360App());
}

const Color bg = Color(0xFF030814);
const Color panel = Color(0xFF071326);
const Color cyan = Color(0xFF00E5FF);
const Color pink = Color(0xFFFF28CF);
const Color green = Color(0xFF39FF9C);
const Color yellow = Color(0xFFFFD600);
const Color blue = Color(0xFF087BFF);
const Color muted = Color(0xFFA9BDD6);

// Datos de emisión para configurar PRISM LIVE STUDIO.
// El envío RTMP se hace desde PRISM, no desde el reproductor Flutter.
const String rtmpServerUrl = 'rtmp://ssh101.bozztv.com:1935/ssh101';
const String ssh101StreamKey = 'deportetotal360';
const String channelDisplayName = 'Deporte Total 360°-1';

// URL HLS de salida para reproducir la señal en la APK.
// Comprueba en el panel de SSH101 que esta sea la URL asignada a tu canal.
const String streamUrl =
    'https://live21.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8';

const String agendaUrl = 'https://futbol-libre.cam/';
const String telegramUrl = 'https://t.me/';

class DeporteTotal360App extends StatelessWidget {
  const DeporteTotal360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          backgroundColor: panel,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

void openInside(BuildContext context, String url, String title) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => WebAgendaScreen(
        initialUrl: url,
        pageTitle: title,
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text(
          'DEPORTE TOTAL 360°',
          style: TextStyle(
            color: cyan,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Telegram',
            onPressed: () =>
                openInside(context, telegramUrl, 'TELEGRAM'),
            icon: const Icon(Icons.send_rounded, color: cyan),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SportsBackdrop()),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                _buildHero(),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: 'TU MUNDO DEPORTIVO',
                  color: cyan,
                ),
                const SizedBox(height: 14),
                const SportsRow(),
                const SizedBox(height: 24),
                const SectionTitle(
                  title: 'EXPLORA DEPORTE TOTAL 360°',
                  color: pink,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 520 ? 3 : 2;

                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 11,
                      mainAxisSpacing: 11,
                      childAspectRatio: columns == 3 ? 1.0 : 1.12,
                      children: [
                        FeatureTile(
                          icon: Icons.live_tv_rounded,
                          title: 'EN VIVO',
                          subtitle: 'VER CANAL',
                          color: pink,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LiveScreen(),
                            ),
                          ),
                        ),
                        FeatureTile(
                          icon: Icons.calendar_month_rounded,
                          title: 'AGENDA',
                          subtitle: 'PARTIDOS',
                          color: green,
                          onTap: () => openInside(
                            context,
                            agendaUrl,
                            'AGENDA DEPORTIVA',
                          ),
                        ),
                        FeatureTile(
                          icon: Icons.send_rounded,
                          title: 'TELEGRAM',
                          subtitle: 'CANAL OFICIAL',
                          color: const Color(0xFF28A8E9),
                          onTap: () => openInside(
                            context,
                            telegramUrl,
                            'TELEGRAM',
                          ),
                        ),
                        FeatureTile(
                          icon: Icons.sports_soccer_rounded,
                          title: 'FÚTBOL',
                          subtitle: 'AGENDA',
                          color: cyan,
                          onTap: () => openInside(
                            context,
                            agendaUrl,
                            'AGENDA DE FÚTBOL',
                          ),
                        ),
                        FeatureTile(
                          icon: Icons.favorite_rounded,
                          title: 'DONACIONES',
                          subtitle: 'APOYA EL PROYECTO',
                          color: yellow,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DonationsScreen(),
                            ),
                          ),
                        ),
                        FeatureTile(
                          icon: Icons.emoji_events_rounded,
                          title: 'DEPORTES',
                          subtitle: 'TODOS EN UNO',
                          color: blue,
                          onTap: () => openInside(
                            context,
                            agendaUrl,
                            'AGENDA DEPORTIVA',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF061A3A),
                        Color(0xFF250B40),
                        Color(0xFF062E3C),
                      ],
                    ),
                    border: Border.all(
                      color: pink.withValues(alpha: .8),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: yellow,
                        size: 42,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '¡EL DEPORTE NOS UNE!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cyan,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Fútbol · Baloncesto · Béisbol · Tenis · Voleibol',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'DEPORTE TOTAL 360° · TU PASIÓN, EN TODAS PARTES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF071B46),
            Color(0xFF160B3C),
            Color(0xFF031326),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cyan, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: .12),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 190,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) {
              return const SizedBox(
                height: 150,
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: yellow,
                  size: 80,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'TODO EL DEPORTE EN UN SOLO LUGAR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Agenda deportiva · Directos · Noticias',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class SportsRow extends StatelessWidget {
  const SportsRow({super.key});

  @override
  Widget build(BuildContext context) {
    const sports = [
      (Icons.sports_soccer_rounded, 'FÚTBOL', cyan),
      (Icons.sports_basketball_rounded, 'BÁSQUET', yellow),
      (Icons.sports_tennis_rounded, 'TENIS', green),
      (Icons.sports_baseball_rounded, 'BÉISBOL', pink),
      (Icons.sports_volleyball_rounded, 'VOLEY', blue),
      (Icons.emoji_events_rounded, 'OTROS', Color(0xFFB45CFF)),
    ];

    return Row(
      children: [
        for (final sport in sports)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sport.$3.withValues(alpha: .08),
                    border: Border.all(color: sport.$3),
                  ),
                  child: Icon(sport.$1, color: sport.$3, size: 21),
                ),
                const SizedBox(height: 5),
                Text(
                  sport.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .4,
            ),
          ),
        ),
      ],
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
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
  Widget build(BuildContext context) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: color.withValues(alpha: .9),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34, color: color),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SportsBackdrop extends StatelessWidget {
  const SportsBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: -80,
            child: _glow(190, cyan.withValues(alpha: .035)),
          ),
          Positioned(
            top: 470,
            right: -80,
            child: _glow(220, pink.withValues(alpha: .035)),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 70,
            spreadRadius: 25,
          ),
        ],
      ),
    );
  }
}

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  VideoPlayerController? _player;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _startPlayer();
  }

  Future<void> _startPlayer() async {
    final old = _player;
    _player = null;
    await old?.dispose();

    if (!mounted) return;

    setState(() {
      _loading = true;
      _failed = false;
    });

    final player = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
    );
    _player = player;
    player.addListener(_onPlayerChanged);

    try {
      await player.initialize();

      if (!mounted || _player != player) {
        await player.dispose();
        return;
      }

      await player.play();

      if (!mounted || _player != player) return;

      setState(() {
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || _player != player) return;

      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final ready =
        player != null && player.value.isInitialized && !_failed;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TRANSMISIONES EN VIVO',
          style: TextStyle(
            color: cyan,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle(
            title: 'CANAL EN VIVO DE DEPORTE TOTAL 360°',
            color: pink,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: cyan),
                      )
                    : !ready
                        ? const OfflinePanel()
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: player.value.size.width,
                                    height: player.value.size.height,
                                    child: VideoPlayer(player),
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                onPressed: () {
                                  if (player.value.isPlaying) {
                                    player.pause();
                                  } else {
                                    player.play();
                                  }
                                },
                                iconSize: 40,
                                icon: Icon(
                                  player.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_loading && !ready) ...[
            const Text(
              'No se pudo reproducir la señal. Comprueba que PRISM '
              'esté transmitiendo y que la URL HLS corresponda a tu canal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _startPlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('RECARGAR SEÑAL'),
            ),
          ],
          const SizedBox(height: 18),
          FeatureTile(
            icon: Icons.calendar_month_rounded,
            title: 'AGENDA DE PARTIDOS',
            subtitle: 'CONSULTAR PROGRAMACIÓN',
            color: green,
            onTap: () => openInside(
              context,
              agendaUrl,
              'AGENDA DEPORTIVA',
            ),
          ),
        ],
      ),
    );
  }
}

class OfflinePanel extends StatelessWidget {
  const OfflinePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF07152E),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.portable_wifi_off_rounded,
                color: pink,
                size: 42,
              ),
              SizedBox(height: 10),
              Text(
                'CANAL EN VIVO',
                style: TextStyle(
                  color: cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'SEÑAL NO DISPONIBLE',
                style: TextStyle(
                  color: pink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DONACIONES')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: pink,
                size: 76,
              ),
              const SizedBox(height: 18),
              const Text(
                'APOYA EL PROYECTO',
                style: TextStyle(
                  color: yellow,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Gracias por apoyar DEPORTE TOTAL 360°.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => openInside(
                  context,
                  telegramUrl,
                  'TELEGRAM',
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text('IR A TELEGRAM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}