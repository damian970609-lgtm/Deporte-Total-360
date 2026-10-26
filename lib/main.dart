import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'web_agenda_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeporteTotal360App());
}

const Color bg = Color(0xFF030814);
const Color panel = Color(0xFF09172B);
const Color cyan = Color(0xFF00E5FF);
const Color pink = Color(0xFFFF28CF);
const Color green = Color(0xFF39FF9C);
const Color yellow = Color(0xFFFFD600);
const Color muted = Color(0xFFB4C4D9);

// Sustituye estas URL por la salida HLS que indique tu proveedor de transmisión.
const List<String> streamUrls = <String>[
  'https://live21.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8',
  'https://live20.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8',
];

const String agendaUrl = 'https://futbol-libre.cam/';
const String fallbackAgendaUrl = 'https://www.espn.com/soccer/scoreboard';
// Cambia este enlace por el del canal de Telegram cuando lo crees.
const String telegramUrl = 'https://t.me/';
const String contactUrl = 'https://wa.me/';

void showWeb(
  BuildContext context, {
  String url = agendaUrl,
  String title = 'AGENDA DE PARTIDOS',
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WebAgendaScreen(initialUrl: url, pageTitle: title),
    ),
  );
}

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
      // La agenda se abre automáticamente al arrancar la APK.
      // El botón Atrás lleva a HomeScreen, que queda detrás de esta ruta.
      home: const AgendaStartupScreen(),
    );
  }
}

class AgendaStartupScreen extends StatefulWidget {
  const AgendaStartupScreen({super.key});

  @override
  State<AgendaStartupScreen> createState() => _AgendaStartupScreenState();
}

class _AgendaStartupScreenState extends State<AgendaStartupScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showWeb(context, title: 'AGENDA DE PARTIDOS');
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _openAndReset(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) setState(() => _selectedIndex = 0);
  }

  Future<void> _openAgenda({
    String url = agendaUrl,
    String title = 'AGENDA DE PARTIDOS',
  }) async {
    showWeb(context, url: url, title: title);
    if (mounted) setState(() => _selectedIndex = 0);
  }

  void _onNavigationTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        _openAgenda(title: 'FÚTBOL');
        break;
      case 2:
        _openAndReset(const LiveScreen());
        break;
      case 3:
        _openAgenda(title: 'AGENDA DE PARTIDOS');
        break;
      case 4:
        _openAndReset(const SettingsScreen());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF061A39),
              bg,
              Color(0xFF09091A),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            children: <Widget>[
              const _BrandHeader(),
              const SizedBox(height: 15),
              const _SportsStrip(),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _HomeActionTile(
                      icon: Icons.live_tv_rounded,
                      title: 'TRANSMISIONES',
                      subtitle: 'EN VIVO',
                      color: const Color(0xFFFF3159),
                      onTap: () => _openAndReset(const LiveScreen()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HomeActionTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'AGENDA',
                      subtitle: 'DE PARTIDOS',
                      color: green,
                      onTap: () => _openAgenda(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HomeActionTile(
                      icon: Icons.send_rounded,
                      title: 'TELEGRAM',
                      subtitle: 'COMUNIDAD',
                      color: const Color(0xFF31A9F5),
                      onTap: () => _openAgenda(
                        url: telegramUrl,
                        title: 'TELEGRAM',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: _HomeActionTile(
                      icon: Icons.chat_bubble_rounded,
                      title: 'CONTACTAR',
                      subtitle: 'CON EL CREADOR',
                      color: const Color(0xFF22E88A),
                      horizontal: true,
                      onTap: () => _openAgenda(
                        url: contactUrl,
                        title: 'CONTACTAR CON EL CREADOR',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: _HomeActionTile(
                      icon: Icons.favorite_rounded,
                      title: 'DONACIONES',
                      subtitle: 'APOYA EL PROYECTO',
                      color: yellow,
                      horizontal: true,
                      onTap: () => _openAndReset(const DonationsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const _CommunityBanner(),
              const SizedBox(height: 18),
              const _SectionHeading(
                title: 'PARTIDOS Y RESULTADOS',
                color: cyan,
              ),
              const SizedBox(height: 9),
              _ListActionRow(
                icon: Icons.sports_soccer_rounded,
                title: 'Agenda completa de fútbol',
                subtitle: 'Programación, canales y resultados',
                color: green,
                onTap: () => _openAgenda(),
              ),
              _ListActionRow(
                icon: Icons.play_circle_fill_rounded,
                title: 'Ver transmisiones en vivo',
                subtitle: 'Reproductor de DEPORTE TOTAL 360°',
                color: pink,
                onTap: () => _openAndReset(const LiveScreen()),
              ),
              const SizedBox(height: 12),
              const Text(
                'DEPORTE TOTAL 360°  •  TU PASIÓN, EN TODAS PARTES',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavigationTap,
        backgroundColor: const Color(0xFF050E20),
        selectedItemColor: cyan,
        unselectedItemColor: muted,
        selectedFontSize: 10,
        unselectedFontSize: 9,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer_rounded),
            label: 'Fútbol',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv_rounded),
            label: 'En vivo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF102F5F),
            Color(0xFF0B0D27),
            Color(0xFF12113A),
          ],
        ),
        border: Border.all(color: cyan.withValues(alpha: .6), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cyan.withValues(alpha: .10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 136,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.emoji_events_rounded,
                color: yellow,
                size: 90,
              ),
            ),
          ),
          const Text(
            'TODOS LOS DEPORTES EN UN SOLO LUGAR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'TU PASIÓN, EN TODAS PARTES',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportsStrip extends StatelessWidget {
  const _SportsStrip();

  @override
  Widget build(BuildContext context) {
    const sports = <({String label, IconData icon, Color color})>[
      (
        label: 'FÚTBOL',
        icon: Icons.sports_soccer_rounded,
        color: cyan,
      ),
      (
        label: 'BÁSQUET',
        icon: Icons.sports_basketball_rounded,
        color: yellow,
      ),
      (
        label: 'TENIS',
        icon: Icons.sports_tennis_rounded,
        color: green,
      ),
      (
        label: 'BÉISBOL',
        icon: Icons.sports_baseball_rounded,
        color: pink,
      ),
      (
        label: 'VÓLEY',
        icon: Icons.sports_volleyball_rounded,
        color: Color(0xFF438DFF),
      ),
      (
        label: 'OTROS',
        icon: Icons.emoji_events_rounded,
        color: Color(0xFFB48CFF),
      ),
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final sport = sports[index];
          return Container(
            width: 70,
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: sport.color.withValues(alpha: .7),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: sport.color.withValues(alpha: .07),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(sport.icon, color: sport.color, size: 28),
                const SizedBox(height: 5),
                Text(
                  sport.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: horizontal ? 88 : 112,
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 8 : 5,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                color.withValues(alpha: .11),
                panel,
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: .85),
              width: 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: .10),
                blurRadius: 12,
              ),
            ],
          ),
          child: horizontal
              ? Row(
                  children: <Widget>[
                    Icon(icon, color: color, size: 34),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, color: color, size: 35),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
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
}

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF092B50),
            Color(0xFF18103C),
            Color(0xFF3B0750),
          ],
        ),
        border: Border.all(color: pink.withValues(alpha: .65)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.sports_soccer_rounded,
            color: cyan,
            size: 36,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '¡EL DEPORTE NOS UNE!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Agenda, transmisiones y pasión deportiva.',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.emoji_events_rounded,
            color: yellow,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ],
      );
}

class _ListActionRow extends StatelessWidget {
  const _ListActionRow({
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: .45),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color),
                ],
              ),
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

    String lastError = 'No se recibió una señal HLS reproducible.';
    for (final url in streamUrls) {
      final candidate = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await candidate.initialize().timeout(const Duration(seconds: 14));
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
    final controller = _controller;
    if (!mounted ||
        controller == null ||
        !controller.value.hasError ||
        _failed) {
      return;
    }
    setState(() {
      _loading = false;
      _failed = true;
      _errorMessage =
          controller.value.errorDescription ?? 'Error del reproductor HLS.';
    });
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_checkPlayerError);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null &&
        controller.value.isInitialized &&
        !_failed;
    final ratio = controller != null &&
            controller.value.isInitialized &&
            !_failed &&
            controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
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
        padding: const EdgeInsets.all(15),
        children: <Widget>[
          const _SectionHeading(
            title: 'CANAL DE DEPORTE TOTAL 360°',
            color: pink,
          ),
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
                        : VideoPlayer(controller!),
              ),
            ),
          ),
          if (ready) ...<Widget>[
            const SizedBox(height: 10),
            VideoProgressIndicator(
              controller!,
              allowScrubbing: false,
              colors: const VideoProgressColors(
                playedColor: pink,
                bufferedColor: muted,
                backgroundColor: panel,
              ),
            ),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip:
                      controller!.value.isPlaying ? 'Pausar' : 'Reproducir',
                  onPressed: () async {
                    if (controller!.value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    controller!.value.isPlaying
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
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: green,
                  ),
                ),
              ],
            ),
            if (_activeUrl != null)
              Text(
                'Fuente: $_activeUrl',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
          ] else ...<Widget>[
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
              'Para que haya imagen, el canal debe estar transmitiendo y la URL HLS debe coincidir exactamente con la que indica el proveedor de streaming.',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 15),
          _HomeActionTile(
            icon: Icons.calendar_month_rounded,
            title: 'AGENDA DE PARTIDOS',
            subtitle: 'PROGRAMACIÓN Y RESULTADOS',
            color: green,
            onTap: () => showWeb(context),
          ),
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
            children: <Widget>[
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
                'Verifica tu conexión, el estado EN VIVO del canal y la URL HLS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              if (message != null && message!.isNotEmpty) ...<Widget>[
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
              children: <Widget>[
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AJUSTES')),
        body: ListView(
          padding: const EdgeInsets.all(15),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cyan.withValues(alpha: .4)),
              ),
              child: const Column(
                children: <Widget>[
                  Icon(Icons.settings_rounded, color: cyan, size: 43),
                  SizedBox(height: 8),
                  Text(
                    'DEPORTE TOTAL 360°',
                    style: TextStyle(
                      color: cyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'TU PASIÓN, EN TODAS PARTES',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
              activeThumbColor: cyan,
              title: const Text('Modo oscuro'),
              subtitle: const Text('Interfaz azul y neón'),
              secondary: const Icon(
                Icons.dark_mode_rounded,
                color: cyan,
              ),
            ),
            SwitchListTile(
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
              activeThumbColor: green,
              title: const Text('Notificaciones'),
              subtitle: const Text('Preferencias visuales de la aplicación'),
              secondary: const Icon(
                Icons.notifications_active_rounded,
                color: green,
              ),
            ),
            const Divider(color: panel),
            const ListTile(
              leading: Icon(Icons.language_rounded, color: cyan),
              title: Text('Idioma'),
              subtitle: Text('Español'),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline_rounded, color: cyan),
              title: Text('Acerca de'),
              subtitle: Text('DEPORTE TOTAL 360°'),
            ),
          ],
        ),
      );
}