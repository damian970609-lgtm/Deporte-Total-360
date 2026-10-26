import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'web_agenda_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeporteTotal360App());
}

const Color bg = Color(0xFF020817);
const Color panel = Color(0xFF071B35);
const Color cyan = Color(0xFF00E5FF);
const Color pink = Color(0xFFFF28CF);
const Color green = Color(0xFF39FF9C);
const Color yellow = Color(0xFFFFD600);
const Color muted = Color(0xFFB4C4D9);

// Estas direcciones son marcadores de transmisión.
// Sustitúyelas por las URL de vídeo que tengas autorización para utilizar.
const List<String> streamUrls = <String>[
  'https://live21.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8',
  'https://live20.bozztv.com/akamaissh101/ssh101/deportetotal360/playlist.m3u8',
];

const String agendaUrl = 'https://futbol-libre.cam/';
const String fallbackAgendaUrl =
    'https://www.espn.com/soccer/scoreboard';

// Cuando crees el canal, reemplaza esta dirección por su enlace.
const String telegramUrl = 'https://t.me/';

// Sustituye esta dirección por el enlace de contacto completo.
const String contactUrl = 'https://wa.me/';

void showWeb(
  BuildContext context, {
  String url = agendaUrl,
  String title = 'AGENDA DE PARTIDOS',
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WebAgendaScreen(
        initialUrl: url,
        pageTitle: title,
      ),
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
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),

      // La app empieza en la portada.
      // La agenda se abre únicamente cuando se pulsa su acceso.
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );

    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  Future<void> _openAgenda({
    String url = agendaUrl,
    String title = 'AGENDA DE PARTIDOS',
  }) async {
    showWeb(
      context,
      url: url,
      title: title,
    );

    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
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
        _openPage(const LiveScreen());
        break;

      case 3:
        _openAgenda();
        break;

      case 4:
        _openPage(const SettingsScreen());
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
              Color(0xFF051A3A),
              bg,
              Color(0xFF09051B),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _BrandHeader(),
                const SizedBox(height: 7),

                const Text(
                  'TODOS LOS DEPORTES EN UN SOLO LUGAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),

                const SizedBox(height: 9),
                const _SportsStrip(),
                const SizedBox(height: 12),

                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HomeActionTile(
                        icon: Icons.live_tv_rounded,
                        title: 'TRANSMISIONES',
                        subtitle: 'EN VIVO',
                        color: const Color(0xFFFF3159),
                        onTap: () =>
                            _openPage(const LiveScreen()),
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

                const SizedBox(height: 8),

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
                        onTap: () =>
                            _openPage(const DonationsScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 11),
                const _CommunityBanner(),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavigationTap,
        backgroundColor: const Color(0xFF030A18),
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
      height: 176,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.15,
          colors: <Color>[
            Color(0xFF12336A),
            Color(0xFF040B1B),
            Color(0xFF060819),
          ],
        ),
        border: Border.all(
          color: cyan.withValues(alpha: .40),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cyan.withValues(alpha: .12),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
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
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sports.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final sport = sports[index];

          return Container(
            width: 59,
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: sport.color.withValues(alpha: .8),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: sport.color.withValues(alpha: .10),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  sport.icon,
                  color: sport.color,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  sport.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
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
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: horizontal ? 73 : 96,
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 7 : 3,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                color.withValues(alpha: .18),
                panel,
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: .95),
              width: 1.15,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: .12),
                blurRadius: 10,
              ),
            ],
          ),
          child: horizontal
              ? Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      color: color,
                      size: 30,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 7,
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
                    Icon(
                      icon,
                      color: color,
                      size: 31,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 7,
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
      height: 89,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF061B47),
            Color(0xFF351054),
            Color(0xFF071D45),
          ],
        ),
        border: Border.all(
          color: pink.withValues(alpha: .8),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: pink.withValues(alpha: .12),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.sports_soccer_rounded,
            color: cyan,
            size: 34,
          ),
          const SizedBox(width: 7),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '¡EL DEPORTE NOS UNE!',
                  style: TextStyle(
                    color: yellow,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Agenda, transmisiones y pasión deportiva.',
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.emoji_events_rounded,
            color: yellow,
            size: 31,
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
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    for (final url in streamUrls) {
      final candidate = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      try {
        await candidate.initialize();
        await candidate.setLooping(true);

        if (!mounted) {
          await candidate.dispose();
          return;
        }

        setState(() {
          _controller = candidate;
          _loading = false;
          _error = null;
        });

        return;
      } catch (_) {
        await candidate.dispose();
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error =
            'La transmisión no está disponible ahora. '
            'Puedes abrir la agenda para buscar otro enlace '
            'de partido.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRANSMISIONES EN VIVO'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF071C3D),
              bg,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator(color: cyan)
              : _error != null ||
                      player == null ||
                      !player.value.isInitialized
                  ? _OfflinePanel(
                      message: _error ??
                          'La emisión todavía no está disponible.',
                      onAgenda: () => showWeb(context),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        AspectRatio(
                          aspectRatio: player.value.aspectRatio,
                          child: VideoPlayer(player),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            if (player.value.isPlaying) {
                              player.pause();
                            } else {
                              player.play();
                            }
                            setState(() {});
                          },
                          icon: Icon(
                            player.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            player.value.isPlaying
                                ? 'PAUSAR'
                                : 'REPRODUCIR',
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({
    required this.message,
    required this.onAgenda,
  });

  final String message;
  final VoidCallback onAgenda;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pink),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.live_tv_rounded,
            color: pink,
            size: 56,
          ),
          const SizedBox(height: 13),
          const Text(
            'TRANSMISIÓN NO DISPONIBLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cyan,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAgenda,
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('ABRIR AGENDA'),
          ),
        ],
      ),
    );
  }
}

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DONACIONES'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pink),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.favorite_rounded,
                  color: pink,
                  size: 60,
                ),
                SizedBox(height: 14),
                Text(
                  'APOYA DEPORTE TOTAL 360°',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Gracias por ayudar a mantener vivo este proyecto. '
                  'Añade aquí tu enlace de donación cuando lo tengas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AJUSTES'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SwitchListTile(
            title: const Text('Modo oscuro'),
            secondary: const Icon(
              Icons.dark_mode_rounded,
              color: cyan,
            ),
            value: _darkMode,
            onChanged: (value) =>
                setState(() => _darkMode = value),
          ),
          const Divider(color: Color(0xFF203B60)),
          SwitchListTile(
            title: const Text('Notificaciones'),
            secondary: const Icon(
              Icons.notifications_active_rounded,
              color: green,
            ),
            value: _notifications,
            onChanged: (value) =>
                setState(() => _notifications = value),
          ),
          const Divider(color: Color(0xFF203B60)),
          const ListTile(
            leading: Icon(
              Icons.language_rounded,
              color: yellow,
            ),
            title: Text('Idioma'),
            subtitle: Text('Español'),
          ),
          const Divider(color: Color(0xFF203B60)),
          const ListTile(
            leading: Icon(
              Icons.info_outline_rounded,
              color: pink,
            ),
            title: Text('Acerca de'),
            subtitle: Text('DEPORTE TOTAL 360°'),
          ),
          const SizedBox(height: 18),
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 145,
              fit: BoxFit.contain,
            ),
          ),
          const Center(
            child: Text(
              'TU PASIÓN, EN TODAS PARTES',
              style: TextStyle(
                color: cyan,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}