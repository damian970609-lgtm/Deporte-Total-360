import 'package:flutter/material.dart';
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

/// Fondo de marca reutilizable en todas las pantallas.
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
          opacity: 0.15,
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

  void _navigationTap(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        showWeb(context, title: 'FÚTBOL');
        break;
      case 2:
        _openPage(const LiveScreen());
        break;
      case 3:
        showWeb(context);
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
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              12, 10, 12, 16,
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
                const SizedBox(height: 12),
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
                        onTap: () =>
                            _openPage(const LiveScreen()),
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
                    const SizedBox(width: 9),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.send_rounded,
                        title: 'TELEGRAM',
                        subtitle: 'COMUNIDAD',
                        color: const Color(0xFF31A9F5),
                        onTap: () => showWeb(
                          context,
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
                      child: _ActionTile(
                        horizontal: true,
                        icon: Icons.chat_bubble_rounded,
                        title: 'CONTACTAR',
                        subtitle: 'CON EL CREADOR',
                        color: green,
                        onTap: () => showWeb(
                          context,
                          url: contactUrl,
                          title: 'CONTACTAR',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _ActionTile(
                        horizontal: true,
                        icon: Icons.favorite_rounded,
                        title: 'DONACIONES',
                        subtitle: 'APOYA EL PROYECTO',
                        color: yellow,
                        onTap: () =>
                            _openPage(const DonationsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
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
                        color: pink.withValues(alpha: .18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(
                        Icons.sports_soccer_rounded,
                        color: cyan,
                        size: 34,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                              'Agenda, resultados y pasión deportiva.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.emoji_events_rounded,
                        color: yellow,
                        size: 31,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _navigationTap,
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

class _SportsStrip extends StatelessWidget {
  const _SportsStrip();

  @override
  Widget build(BuildContext context) {
    const sports =
        <({String label, IconData icon, Color color})>[
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
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sports.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sport = sports[index];

          return Container(
            width: 70,
            padding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 3,
            ),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: sport.color.withValues(alpha: .85),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: sport.color.withValues(alpha: .15),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  sport.icon,
                  color: sport.color,
                  size: 27,
                ),
                const SizedBox(height: 4),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: horizontal ? 76 : 102,
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                color.withValues(alpha: .23),
                panel,
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: .95),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: .32),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: color.withValues(alpha: .16),
                blurRadius: 11,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: horizontal
              ? Row(
                  children: <Widget>[
                    Icon(icon, color: color, size: 29),
                    const SizedBox(width: 7),
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
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
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
                    Icon(icon, color: color, size: 31),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 7,
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
                      'Los enlaces de reproducción directa anteriores '
                      'no eran fuentes verificadas. Abre la agenda '
                      'para seleccionar el reproductor disponible. '
                      'La app no puede inventar un enlace de emisión válido.',
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
                name: 'PRIM',
                color: pink,
                onTap: () => showWeb(
                  context,
                  title: 'PRIM · REPRODUCTOR',
                ),
              ),
              const SizedBox(height: 12),
              _ChannelTile(
                name: 'SSH101',
                color: cyan,
                onTap: () => showWeb(
                  context,
                  title: 'SSH101 · REPRODUCTOR',
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
                'ABRIR AGENDA',
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
        title: const Text('DONACIONES'),
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
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: pink.withValues(alpha: .17),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
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
                    'Gracias por ayudar a mantener vivo este '
                    'proyecto. Añade aquí tu enlace de donación '
                    'cuando lo tengas.',
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
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AJUSTES'),
      ),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SwitchListTile(
              tileColor: panel.withValues(alpha: .9),
              secondary: const Icon(
                Icons.notifications_active_rounded,
                color: green,
              ),
              title: const Text('Notificaciones'),
              value: _notifications,
              onChanged: (value) =>
                  setState(() => _notifications = value),
            ),
            const Divider(
              color: Color(0xFF203B60),
            ),
            const ListTile(
              tileColor: Color(0xD5071B35),
              leading: Icon(
                Icons.language_rounded,
                color: yellow,
              ),
              title: Text('Idioma'),
              subtitle: Text('Español'),
            ),
            const Divider(
              color: Color(0xFF203B60),
            ),
            const ListTile(
              tileColor: Color(0xD5071B35),
              leading: Icon(
                Icons.info_outline_rounded,
                color: pink,
              ),
              title: Text('Acerca de'),
              subtitle: Text('DEPORTE TOTAL 360°'),
            ),
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/images/app_icon.png',
                height: 145,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_soccer_rounded,
                  color: cyan,
                  size: 80,
                ),
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
      ),
    );
  }
}