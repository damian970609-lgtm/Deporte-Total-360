import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

const String agendaUrl = 'https://futbol-libre.cam/';

// Añade aquí las URL válidas de tus reproductores.
// Déjalas vacías hasta disponer de sus direcciones reales.
const String prismStreamUrl = '';
const String ssh101StreamUrl = '';

const String fallbackAgendaUrl =
    'https://www.espn.com/soccer/scoreboard';
const String telegramUrl = 'https://t.me/';
const String contactUrl = 'https://wa.me/';

Future<void> showWeb(
  BuildContext context, {
  String url = agendaUrl,
  String title = 'AGENDA DE PARTIDOS',
}) async {
  await Navigator.of(context).push<void>(
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
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Opacity(
          opacity: 0.13,
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const SizedBox.shrink(),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xE6051A3A),
                Color(0xF0020817),
                Color(0xE609051B),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openPage(
    BuildContext context,
    Widget page,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              12, 10, 12, 20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 168,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                      color: cyan.withValues(alpha: 0.65),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: cyan.withValues(alpha: 0.20),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(
                      Icons.emoji_events_rounded,
                      color: yellow,
                      size: 86,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TODOS LOS DEPORTES EN UN SOLO LUGAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: .4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                const _SportsStrip(),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.live_tv_rounded,
                        title: 'TRANSMISIONES',
                        subtitle: 'EN VIVO',
                        color: const Color(0xFFFF3159),
                        onTap: () => _openPage(
                          context,
                          const LiveScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.calendar_month_rounded,
                        title: 'AGENDA',
                        subtitle: 'DE PARTIDOS',
                        color: green,
                        onTap: () => showWeb(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.send_rounded,
                        title: 'TELEGRAM',
                        subtitle: 'CANAL OFICIAL',
                        color: cyan,
                        onTap: () => _openExternalInfo(
                          context,
                          telegramUrl,
                          'Telegram',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'APOYO',
                        subtitle: 'AL PROYECTO',
                        color: pink,
                        onTap: () => _openPage(
                          context,
                          const DonationsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => showWeb(context),
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                  ),
                  label: const Text(
                    'VER AGENDA DE PARTIDOS',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openExternalInfo(
                    context,
                    contactUrl,
                    'Contacto',
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('CONTACTO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: green,
                    side: const BorderSide(color: green),
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

Future<void> _openExternalInfo(
  BuildContext context,
  String url,
  String label,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir $label.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir $label.'),
        ),
      );
    }
  }
}

class _SportsStrip extends StatelessWidget {
  const _SportsStrip();

  @override
  Widget build(BuildContext context) {
    const entries = <(IconData, String)>[
      (Icons.sports_soccer_rounded, 'FÚTBOL'),
      (Icons.sports_basketball_rounded, 'BALONCESTO'),
      (Icons.sports_tennis_rounded, 'TENIS'),
      (Icons.sports_mma_rounded, 'COMBATE'),
      (Icons.sports_volleyball_rounded, 'VÓLEIBOL'),
    ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final item = entries[index];

          return Container(
            width: 92,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: panel.withValues(alpha: .84),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: cyan.withValues(alpha: .35),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  item.$1,
                  color: cyan,
                  size: 25,
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 106,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: .85),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: .12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
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

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRANSMISIONES EN VIVO'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: panel.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cyan.withValues(alpha: .8),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cyan.withValues(alpha: .16),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Column(
                  children: <Widget>[
                    Icon(
                      Icons.live_tv_rounded,
                      color: pink,
                      size: 55,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'REPRODUCTORES DE CANALES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Abre la agenda y selecciona el reproductor '
                      'disponible. La app evita abrir ventanas '
                      'emergentes, pero necesita que el sitio '
                      'tenga un reproductor incrustado válido '
                      'para poder reproducirlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        height: 1.45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ChannelTile(
                name: 'PRISM',
                color: pink,
                onTap: () => showWeb(
                  context,
                  url: prismStreamUrl.trim().isEmpty
                      ? agendaUrl
                      : prismStreamUrl.trim(),
                  title: 'PRISM · EN VIVO AQUÍ',
                ),
              ),
              const SizedBox(height: 12),
              _ChannelTile(
                name: 'SSH101',
                color: cyan,
                onTap: () => showWeb(
                  context,
                  url: ssh101StreamUrl.trim().isEmpty
                      ? agendaUrl
                      : ssh101StreamUrl.trim(),
                  title: 'SSH101 · EN VIVO AQUÍ',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => showWeb(context),
                icon: const Icon(
                  Icons.calendar_month_rounded,
                ),
                label: const Text(
                  'ABRIR AGENDA DE PARTIDOS',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.name,
    required this.color,
    required this.onTap,
  });

  final String name;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: .2),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.play_circle_fill_rounded,
                color: color,
                size: 39,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Text(
                'EN VIVO AQUÍ',
                style: TextStyle(
                  color: cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: cyan,
                size: 16,
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
      appBar: AppBar(
        title: const Text('APOYO AL PROYECTO'),
      ),
      body: AppBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: panel.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pink),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.favorite_rounded,
                    color: pink,
                    size: 54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'GRACIAS POR APOYAR',
                    style: TextStyle(
                      color: cyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Esta sección queda preparada para añadir '
                    'el enlace oficial de apoyo cuando esté disponible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}