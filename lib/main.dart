import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'agenda_screen.dart';
import 'fantasy_screen.dart';
import 'web_agenda_screen.dart';

// Identidad visual de DEPORTE TOTAL 360°: azul noche, cian, rosa y verde neón.
const Color appBg = Color(0xFF030814);
const Color appPanel = Color(0xFF071326);
const Color appPanel2 = Color(0xFF0B1B31);
const Color appLine = Color(0xFF123D65);
const Color appCyan = Color(0xFF00E5FF);
const Color appBlue = Color(0xFF087BFF);
const Color appPink = Color(0xFFFF28CF);
const Color appGreen = Color(0xFF39FF9C);
const Color appYellow = Color(0xFFFFD600);
const Color appRed = Color(0xFFFF3155);
const Color appMuted = Color(0xFFA9BDD6);

// Se conservan las direcciones de servidor que ya existían en el proyecto.
// No se usan para los partidos de la agenda; la agenda solo acepta fuentes
// verificadas que le sean suministradas por una API autorizada.
const String rtmpBase = 'rtmp://ssh101.bozztv.com/ssh101/';
const String hlsBase = 'https://live21.bozztv.com/akamaissh101/ssh101/';
const String contactUrl = 'https://wa.me/5927214741';
const String settingsPhotoAsset =
    'assets/images/file_000000006048820e9e0720f1adf548f1.png';

// No se inventa el enlace del canal Telegram: queda vacío hasta que el dueño
// guarde su enlace público real desde Ajustes.
enum AppLanguage { spanish, english, portuguese, french }

final ValueNotifier<AppLanguage> appLanguage =
    ValueNotifier<AppLanguage>(AppLanguage.spanish);
final ValueNotifier<String> channelSlug = ValueNotifier<String>('');
final ValueNotifier<String> telegramLink = ValueNotifier<String>('');

String languageCode(AppLanguage language) {
  switch (language) {
    case AppLanguage.spanish:
      return 'es';
    case AppLanguage.english:
      return 'en';
    case AppLanguage.portuguese:
      return 'pt';
    case AppLanguage.french:
      return 'fr';
  }
}

AppLanguage parseLanguage(String? code) {
  switch (code) {
    case 'en':
      return AppLanguage.english;
    case 'pt':
      return AppLanguage.portuguese;
    case 'fr':
      return AppLanguage.french;
    default:
      return AppLanguage.spanish;
  }
}

const Map<String, Map<AppLanguage, String>> _labels =
    <String, Map<AppLanguage, String>>{
  'title': <AppLanguage, String>{
    AppLanguage.spanish: 'DEPORTE TOTAL 360°',
    AppLanguage.english: 'TOTAL SPORTS 360°',
    AppLanguage.portuguese: 'ESPORTE TOTAL 360°',
    AppLanguage.french: 'SPORT TOTAL 360°',
  },
  'tagline': <AppLanguage, String>{
    AppLanguage.spanish: 'TODOS LOS DEPORTES EN UN SOLO LUGAR',
    AppLanguage.english: 'ALL SPORTS IN ONE PLACE',
    AppLanguage.portuguese: 'TODOS OS ESPORTES EM UM SÓ LUGAR',
    AppLanguage.french: 'TOUS LES SPORTS AU MÊME ENDROIT',
  },
  'home': <AppLanguage, String>{
    AppLanguage.spanish: 'Inicio',
    AppLanguage.english: 'Home',
    AppLanguage.portuguese: 'Início',
    AppLanguage.french: 'Accueil',
  },
  'football': <AppLanguage, String>{
    AppLanguage.spanish: 'Fútbol',
    AppLanguage.english: 'Football',
    AppLanguage.portuguese: 'Futebol',
    AppLanguage.french: 'Football',
  },
  'live': <AppLanguage, String>{
    AppLanguage.spanish: 'En vivo',
    AppLanguage.english: 'Live',
    AppLanguage.portuguese: 'Ao vivo',
    AppLanguage.french: 'En direct',
  },
  'agenda': <AppLanguage, String>{
    AppLanguage.spanish: 'Agenda',
    AppLanguage.english: 'Schedule',
    AppLanguage.portuguese: 'Agenda',
    AppLanguage.french: 'Agenda',
  },
  'settings': <AppLanguage, String>{
    AppLanguage.spanish: 'Ajustes',
    AppLanguage.english: 'Settings',
    AppLanguage.portuguese: 'Configurações',
    AppLanguage.french: 'Réglages',
  },
  'streams': <AppLanguage, String>{
    AppLanguage.spanish: 'TRANSMISIONES EN VIVO',
    AppLanguage.english: 'LIVE STREAMS',
    AppLanguage.portuguese: 'TRANSMISSÕES AO VIVO',
    AppLanguage.french: 'DIFFUSIONS EN DIRECT',
  },
  'matches': <AppLanguage, String>{
    AppLanguage.spanish: 'AGENDA DE PARTIDOS',
    AppLanguage.english: 'MATCH SCHEDULE',
    AppLanguage.portuguese: 'AGENDA DE JOGOS',
    AppLanguage.french: 'CALENDRIER DES MATCHS',
  },
  'telegram': <AppLanguage, String>{
    AppLanguage.spanish: 'TELEGRAM',
    AppLanguage.english: 'TELEGRAM',
    AppLanguage.portuguese: 'TELEGRAM',
    AppLanguage.french: 'TELEGRAM',
  },
  'contact': <AppLanguage, String>{
    AppLanguage.spanish: 'CONTACTAR CON EL CREADOR',
    AppLanguage.english: 'CONTACT THE CREATOR',
    AppLanguage.portuguese: 'CONTACTAR O CRIADOR',
    AppLanguage.french: 'CONTACTER LE CRÉATEUR',
  },
  'donations': <AppLanguage, String>{
    AppLanguage.spanish: 'DONACIONES',
    AppLanguage.english: 'DONATIONS',
    AppLanguage.portuguese: 'DOAÇÕES',
    AppLanguage.french: 'DONS',
  },
};

String tr(String key) => _labels[key]?[appLanguage.value] ?? key;
String buildRtmpUrl(String channel) => '$rtmpBase$channel';
String buildHlsUrl(String channel) => '$hlsBase$channel/playlist.m3u8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    appLanguage.value = parseLanguage(prefs.getString('app_language'));
    channelSlug.value = prefs.getString('ssh101_channel') ?? '';
    telegramLink.value = prefs.getString('telegram_public_link') ?? '';
  } catch (_) {
    // La app puede abrirse aunque el almacenamiento local no esté disponible.
  }
  runApp(const DeporteTotal360App());
}

class DeporteTotal360App extends StatelessWidget {
  const DeporteTotal360App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) => MaterialApp(
        title: tr('title'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: appBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: appCyan,
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: appBg,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: appPanel,
            labelStyle: const TextStyle(color: appMuted),
            hintStyle: const TextStyle(color: appMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: appLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: appLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: appCyan, width: 1.4),
            ),
          ),
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _homeTab = 0;
  static const int _footballTab = 1;
  static const int _agendaWebTab = 3;
  static const int _settingsTab = 4;

  final GlobalKey<WebAgendaScreenState> _webAgendaKey =
      GlobalKey<WebAgendaScreenState>();

  int _selectedIndex = _homeTab;
  String _agendaSport = 'Fútbol';
  bool _handlingBack = false;

  void _selectTab(int index) {
    if (index < 0 || index > _settingsTab) return;
    setState(() {
      _selectedIndex = index;
      if (index == _footballTab) _agendaSport = 'Fútbol';
    });
  }

  void _selectSport(String sport) {
    setState(() {
      _agendaSport = sport;
      // Los mosaicos abren la agenda nativa filtrada por deporte.
      // La pestaña inferior Agenda abre la web dentro de la app.
      _selectedIndex = _footballTab;
    });
  }

  Future<void> _openFantasy() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const FantasyScreen(),
      ),
    );
  }

  Future<void> _openDonations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DonationsScreen(),
      ),
    );
  }

  Future<void> _openTelegram() async {
    final link = telegramLink.value.trim();
    if (link.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: appPanel,
          title: const Text(
            'Canal de Telegram',
            style: TextStyle(color: appCyan, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Este espacio queda reservado para tu canal. Todavía no hay un '
            'enlace público configurado; no abriremos un canal genérico ni '
            'uno inventado.',
            style: TextStyle(color: appMuted, height: 1.45),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _selectTab(_settingsTab);
              },
              child: const Text('Configurar enlace'),
            ),
          ],
        ),
      );
      return;
    }
    await openExternalLink(context, link, label: 'Telegram');
  }

  Future<void> _handleSystemBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      // 1. Si estamos en la web integrada, retrocede dentro de ella.
      if (_selectedIndex == _agendaWebTab) {
        final handled =
            await _webAgendaKey.currentState?.handleSystemBack() ?? false;
        if (handled) return;
      }

      // 2. Desde cualquier otra sección vuelve a Inicio.
      if (_selectedIndex != _homeTab) {
        if (mounted) setState(() => _selectedIndex = _homeTab);
        return;
      }

      // 3. Solo en Inicio se pregunta si se desea cerrar la app.
      if (!mounted) return;
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: appPanel,
          title: const Text(
            'Salir de Deporte Total 360°',
            style: TextStyle(color: appCyan, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            '¿Quieres cerrar la aplicación?',
            style: TextStyle(color: appMuted),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (shouldExit == true) await SystemNavigator.pop();
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeDashboard(
        onNavigate: _selectTab,
        onSportSelected: _selectSport,
        onTelegram: _openTelegram,
        onContact: () => openExternalLink(
          context,
          contactUrl,
          label: 'WhatsApp',
        ),
        onDonations: _openDonations,
        onFantasy: _openFantasy,
      ),
      AgendaScreen(
        key: ValueKey<String>('football-$_agendaSport'),
        initialSport: _agendaSport,
      ),
      const LiveScreen(),
      WebAgendaScreen(
        key: _webAgendaKey,
        onExit: () => _selectTab(_homeTab),
      ),
      const SettingsScreen(),
    ];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: appBg,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020B19),
            border: const Border(top: BorderSide(color: appLine)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: appCyan.withAlpha(18),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              height: 64,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
              backgroundColor: const Color(0xFF020B19),
              indicatorColor: appBlue.withAlpha(95),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(
                    Icons.home_rounded,
                    color: appCyan,
                  ),
                  label: tr('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.sports_soccer_outlined),
                  selectedIcon: const Icon(
                    Icons.sports_soccer_rounded,
                    color: appCyan,
                  ),
                  label: tr('football'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.live_tv_outlined),
                  selectedIcon: const Icon(
                    Icons.live_tv_rounded,
                    color: appPink,
                  ),
                  label: tr('live'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(
                    Icons.calendar_month_rounded,
                    color: appGreen,
                  ),
                  label: tr('agenda'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(
                    Icons.settings_rounded,
                    color: appCyan,
                  ),
                  label: tr('settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.25,
              colors: <Color>[
                Color(0xFF101B42),
                appBg,
                Color(0xFF08071B),
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: Opacity(
            opacity: .035,
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Fondo original de Ajustes: conserva la fotografía del proyecto y la oscurece
/// para que los controles sigan siendo legibles.
class SettingsBackdrop extends StatelessWidget {
  const SettingsBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          settingsPhotoAsset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: appBg),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66020817),
                Color(0xB3020817),
                Color(0xF2020817),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.onNavigate,
    required this.onSportSelected,
    required this.onTelegram,
    required this.onContact,
    required this.onDonations,
    required this.onFantasy,
  });

  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onSportSelected;
  final VoidCallback onTelegram;
  final VoidCallback onContact;
  final VoidCallback onDonations;
  final VoidCallback onFantasy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.emoji_events_rounded,
                  color: appCyan,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                tr('title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: appCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: .35,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: tr('settings'),
            onPressed: () => onNavigate(4),
            icon: const Icon(Icons.settings_rounded, color: appCyan),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _BrandHero(),
                const SizedBox(height: 10),
                Text(
                  tr('tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: _SectionHeading(
                        title: 'TODOS LOS DEPORTES',
                        icon: Icons.public_rounded,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigate(3),
                      child: const Text(
                        'Explorar →',
                        style: TextStyle(color: appCyan, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.18,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _SportTile(
                      title: 'FÚTBOL',
                      subtitle: 'Ligas • Copas',
                      icon: Icons.sports_soccer_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Fútbol'),
                    ),
                    _SportTile(
                      title: 'BÁSQUET',
                      subtitle: 'NBA • FIBA',
                      icon: Icons.sports_basketball_rounded,
                      color: appYellow,
                      onTap: () => onSportSelected('Básquet'),
                    ),
                    _SportTile(
                      title: 'BÉISBOL',
                      subtitle: 'MLB • Ligas',
                      icon: Icons.sports_baseball_rounded,
                      color: appPink,
                      onTap: () => onSportSelected('Béisbol'),
                    ),
                    _SportTile(
                      title: 'TENIS',
                      subtitle: 'ATP • WTA',
                      icon: Icons.sports_tennis_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Tenis'),
                    ),
                    _SportTile(
                      title: 'VÓLEY',
                      subtitle: 'Ligas • Torneos',
                      icon: Icons.sports_volleyball_rounded,
                      color: appBlue,
                      onTap: () => onSportSelected('Vóley'),
                    ),
                    _SportTile(
                      title: 'OTROS',
                      subtitle: 'Boxeo • Motor',
                      icon: Icons.emoji_events_rounded,
                      color: appCyan,
                      onTap: () => onSportSelected('Otros'),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                const _SectionHeading(
                  title: 'ACCESO RÁPIDO',
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 9),
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: .96,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _ActionTile(
                      title: tr('streams'),
                      subtitle: 'Ver canales',
                      icon: Icons.live_tv_rounded,
                      color: appRed,
                      onTap: () => onNavigate(2),
                    ),
                    _ActionTile(
                      title: tr('matches'),
                      subtitle: 'Calendario completo',
                      icon: Icons.calendar_month_rounded,
                      color: appGreen,
                      onTap: () => onNavigate(3),
                    ),
                    _ActionTile(
                      title: tr('telegram'),
                      subtitle: 'Canal oficial',
                      icon: Icons.send_rounded,
                      color: appBlue,
                      onTap: onTelegram,
                    ),
                    _ActionTile(
                      title: 'FANTASY',
                      subtitle: 'Jugar y competir',
                      icon: Icons.emoji_events_rounded,
                      color: appPink,
                      onTap: onFantasy,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ActionTile(
                        title: tr('contact'),
                        subtitle: 'En caso de fallas',
                        icon: Icons.chat_rounded,
                        color: appGreen,
                        onTap: onContact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionTile(
                        title: tr('donations'),
                        subtitle: 'Apoya el proyecto',
                        icon: Icons.favorite_rounded,
                        color: appYellow,
                        onTap: onDonations,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFF07172D),
                        Color(0xFF10113A),
                        Color(0xFF071B2D),
                      ],
                    ),
                    border: Border.all(color: appCyan.withAlpha(110)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: appBlue.withAlpha(24), blurRadius: 18),
                    ],
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.sports_rounded, color: appPink, size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '¡EL DEPORTE NOS UNE!',
                              style: TextStyle(
                                color: appCyan,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: .5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tu pasión, en todas partes.',
                              style: TextStyle(color: appMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.bolt_rounded, color: appYellow, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'La agenda mostrará eventos y enlaces de reproducción cuando '
                  'haya una fuente real y autorizada conectada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appMuted,
                    fontSize: 10,
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

class _BrandHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 178,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.25,
          colors: <Color>[
            Color(0xFF10366B),
            Color(0xFF080D25),
            Color(0xFF040816),
          ],
        ),
        border: Border.all(color: appCyan.withAlpha(170)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: appCyan.withAlpha(30),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(color: appPink.withAlpha(18), blurRadius: 20),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.emoji_events_rounded, color: appYellow, size: 50),
            SizedBox(height: 8),
            Text(
              'DEPORTE TOTAL 360°',
              style: TextStyle(
                color: appCyan,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Icon(icon, color: appCyan, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: .45,
              ),
            ),
          ),
        ],
      );
}

class _SportTile extends StatelessWidget {
  const _SportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[color.withAlpha(32), appPanel],
            ),
            border: Border.all(color: color.withAlpha(175)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withAlpha(18), blurRadius: 12),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: appMuted, fontSize: 8),
              ),
            ],
          ),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[color.withAlpha(36), const Color(0xFF050C1D)],
            ),
            border: Border.all(color: color.withAlpha(215)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withAlpha(30), blurRadius: 14),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 29),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
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
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: appMuted, fontSize: 9),
              ),
            ],
          ),
        ),
      );
}

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  Future<void> _openPlayer(BuildContext context) async {
    final slug = channelSlug.value.trim();
    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero configura tu identificador de canal en Ajustes.',
          ),
        ),
      );
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerScreen(channel: slug),
      ),
    );
  }

  Future<void> _openEncoder(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const EncoderConfigScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        title: Text(
          tr('streams'),
          style: const TextStyle(
            color: appCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: appPanel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: appCyan.withAlpha(170)),
                ),
                child: const Column(
                  children: <Widget>[
                    Icon(Icons.live_tv_rounded, color: appPink, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'CANAL EN VIVO DE DEPORTE TOTAL 360°',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appCyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'El reproductor necesita un canal válido y una señal '
                      'activa. Si el servidor está fuera de línea, se '
                      'mostrará el error y podrás reintentar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _LiveActionCard(
                title: 'PRISM LIVE STUDIO',
                subtitle: 'Configurar datos para emitir desde tu encoder.',
                icon: Icons.settings_input_antenna_rounded,
                color: appPink,
                onTap: () => _openEncoder(context),
              ),
              const SizedBox(height: 10),
              _LiveActionCard(
                title: 'SSH101 • REPRODUCCIÓN',
                subtitle: 'Abrir la señal del canal configurado en Ajustes.',
                icon: Icons.play_circle_fill_rounded,
                color: appGreen,
                onTap: () => _openPlayer(context),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EncoderConfigScreen(),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Ver configuración de emisión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appCyan,
                  side: const BorderSide(color: appCyan),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveActionCard extends StatelessWidget {
  const _LiveActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: appPanel,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withAlpha(185)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 35),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: appMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: appMuted),
            ],
          ),
        ),
      );
}

class EncoderConfigScreen extends StatelessWidget {
  const EncoderConfigScreen({super.key});

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado al portapapeles.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = channelSlug.value.trim();
    final valid =
        slug.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug);
    final rtmp = valid ? buildRtmpUrl(slug) : '${rtmpBase}<TU_CANAL>';
    final hls = valid
        ? buildHlsUrl(slug)
        : '${hlsBase}<TU_CANAL>/playlist.m3u8';

    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        title: const Text(
          'CONFIGURAR TRANSMISIÓN',
          style: TextStyle(
            color: appCyan,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Configura estas direcciones en tu encoder únicamente si '
              'corresponden a tu cuenta y canal activos.',
              style: TextStyle(color: appMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            _CopyInfoCard(
              title: 'Servidor RTMP',
              value: rtmp,
              onCopy: () => _copy(context, rtmp),
            ),
            const SizedBox(height: 10),
            _CopyInfoCard(
              title: 'URL HLS de reproducción',
              value: hls,
              onCopy: () => _copy(context, hls),
            ),
            const SizedBox(height: 16),
            const Text(
              'Si la señal no aparece, verifica el estado de tu canal y '
              'consulta la documentación del servicio. Estas direcciones '
              'por sí solas no garantizan que exista una retransmisión activa.',
              style: TextStyle(color: appMuted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyInfoCard extends StatelessWidget {
  const _CopyInfoCard({
    required this.title,
    required this.value,
    required this.onCopy,
  });

  final String title;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: appPanel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: appLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: appCyan,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Copiar'),
                style: TextButton.styleFrom(foregroundColor: appGreen),
              ),
            ),
          ],
        ),
      );
}

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({super.key, required this.channel});
  final String channel;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final slug = widget.channel.trim();
    if (slug.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug)) {
      setState(() {
        _loading = false;
        _error =
            'El identificador del canal no es válido. Abre Ajustes y revísalo.';
      });
      return;
    }
    final uri = Uri.tryParse(buildHlsUrl(slug));
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      setState(() {
        _loading = false;
        _error = 'La dirección de reproducción no es válida.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo abrir el canal. Puede estar fuera de línea o no '
            'permitir esta conexión.';
      });
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        title: const Text(
          'CANAL EN VIVO',
          style: TextStyle(
            color: appCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: <Widget>[
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appCyan),
              ),
              child: AspectRatio(
                aspectRatio: controller?.value.isInitialized == true
                    ? controller!.value.aspectRatio
                    : 16 / 9,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: appCyan),
                      )
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.portable_wifi_off_rounded,
                                  color: appRed,
                                  size: 42,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _initializePlayer,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reintentar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: appCyan,
                                    side: const BorderSide(color: appCyan),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : controller == null || !controller.value.isInitialized
                            ? const Center(
                                child: Text(
                                  'El reproductor no está disponible.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            : ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller,
                                builder: (context, value, _) => Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    VideoPlayer(controller),
                                    if (!value.isPlaying)
                                      IconButton.filled(
                                        onPressed: () => controller.play(),
                                        iconSize: 44,
                                        icon: const Icon(Icons.play_arrow_rounded),
                                        style: IconButton.styleFrom(
                                          backgroundColor: appBlue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
              ),
            ),
            const SizedBox(height: 12),
            if (controller != null &&
                controller.value.isInitialized &&
                _error == null)
              FilledButton.icon(
                onPressed: () async {
                  if (controller.value.isPlaying) {
                    await controller.pause();
                  } else {
                    await controller.play();
                  }
                  if (mounted) setState(() {});
                },
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  controller.value.isPlaying ? 'Pausar' : 'Reproducir',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: appBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Canal configurado: ${widget.channel}',
              style: const TextStyle(
                color: appCyan,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La reproducción depende de que el servidor entregue una '
              'señal compatible y que tengas permiso para acceder a ella.',
              style: TextStyle(color: appMuted, fontSize: 12, height: 1.45),
            ),
          ],
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
  late final TextEditingController _channelController;
  late final TextEditingController _telegramController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _channelController = TextEditingController(text: channelSlug.value);
    _telegramController = TextEditingController(text: telegramLink.value);
  }

  @override
  void dispose() {
    _channelController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final slug = _channelController.text.trim();
    final link = _telegramController.text.trim();

    if (slug.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El identificador de canal solo puede contener letras, números, '
            'guion y guion bajo.',
          ),
        ),
      );
      return;
    }
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null ||
          uri.scheme != 'https' ||
          (uri.host != 't.me' && uri.host != 'telegram.me')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usa el enlace público real https://t.me/tu_canal.'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ssh101_channel', slug);
      await prefs.setString('telegram_public_link', link);
      channelSlug.value = slug;
      telegramLink.value = link;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Vuelve a intentarlo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setLanguage(AppLanguage? value) async {
    if (value == null) return;
    appLanguage.value = value;
    setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', languageCode(value));
    } catch (_) {
      // El idioma permanece activo durante esta sesión.
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado al portapapeles.')),
      );
    }
  }

  Widget _settingsCard({required Color border, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: appPanel.withAlpha(235),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: border.withAlpha(190)),
          boxShadow: <BoxShadow>[
            BoxShadow(color: border.withAlpha(16), blurRadius: 15),
          ],
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final slug = _channelController.text.trim();
    final valid =
        slug.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug);
    final rtmp = valid ? buildRtmpUrl(slug) : '${rtmpBase}<TU_CANAL>';
    final hls = valid
        ? buildHlsUrl(slug)
        : '${hlsBase}<TU_CANAL>/playlist.m3u8';

    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        title: Text(
          tr('settings').toUpperCase(),
          style: const TextStyle(
            color: appCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      body: SettingsBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: <Widget>[
            Container(
              height: 125,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xDD06152D),
                    Color(0xCC15082D),
                    Color(0xDD031E2B),
                  ],
                ),
                border: Border.all(color: appCyan.withAlpha(200)),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: appCyan.withAlpha(25), blurRadius: 18),
                ],
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.emoji_events_rounded,
                        color: appYellow,
                        size: 62,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'DEPORTE TOTAL 360°',
                          style: TextStyle(
                            color: appCyan,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Ajustes de la aplicación',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'DAMIAN.APK',
                          style: TextStyle(
                            color: appPink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configura tu idioma y tus enlaces oficiales.',
                          style: TextStyle(color: appMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            _settingsCard(
              border: appCyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr('settings'),
                    style: const TextStyle(
                      color: appCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Idioma',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<AppLanguage>(
                    value: appLanguage.value,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: const <DropdownMenuItem<AppLanguage>>[
                      DropdownMenuItem(
                        value: AppLanguage.spanish,
                        child: Text('Español'),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.english,
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.portuguese,
                        child: Text('Português'),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.french,
                        child: Text('Français'),
                      ),
                    ],
                    onChanged: _setLanguage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _settingsCard(
              border: appPink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'CANAL DE TELEGRAM',
                    style: TextStyle(
                      color: appCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Este espacio queda reservado para tu canal real. No se '
                    'abrirá ningún enlace genérico si lo dejas vacío.',
                    style: TextStyle(
                      color: appMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 11),
                  TextField(
                    controller: _telegramController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Enlace público (opcional)',
                      hintText: 'https://t.me/tu_canal',
                      prefixIcon: Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _settingsCard(
              border: appGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'CONFIGURACIÓN DE TRANSMISIÓN',
                    style: TextStyle(
                      color: appCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Escribe el identificador del canal que has creado en el '
                    'servicio de emisión. No pegues contraseñas ni tokens aquí.',
                    style: TextStyle(
                      color: appMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 11),
                  TextField(
                    controller: _channelController,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Identificador de canal',
                      hintText: 'NombreDeTuCanal',
                      prefixIcon: Icon(Icons.live_tv_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: appBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _saving ? 'Guardando…' : 'GUARDAR CONFIGURACIÓN',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CopyInfoCard(
                    title: 'Servidor RTMP para emitir',
                    value: rtmp,
                    onCopy: () => _copy(rtmp),
                  ),
                  const SizedBox(height: 9),
                  _CopyInfoCard(
                    title: 'URL HLS de reproducción',
                    value: hls,
                    onCopy: () => _copy(hls),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              'Las transmisiones requieren que el canal y el servidor estén '
              'activos. La agenda nativa necesita una fuente de calendario '
              'autorizada que todavía no está configurada en este proyecto.',
              style: TextStyle(
                color: appMuted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBg,
        appBar: AppBar(
          title: Text(
            tr('donations'),
            style: const TextStyle(
              color: appCyan,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: AppBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: appPanel,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: appPink),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: appPink.withAlpha(25), blurRadius: 22),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.favorite_rounded, color: appPink, size: 56),
                    SizedBox(height: 13),
                    Text(
                      'GRACIAS POR APOYAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appCyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Tu apoyo ayuda a mantener y mejorar Deporte Total 360°. '
                      'El cobro todavía no está conectado; no se realizará '
                      'ningún pago desde esta pantalla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

Future<void> openExternalLink(
  BuildContext context,
  String value, {
  String label = 'enlace',
}) async {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay un enlace válido configurado para $label.')),
      );
    }
    return;
  }
  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir $label.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir $label.')),
      );
    }
  }
}