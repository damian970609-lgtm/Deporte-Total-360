import 'package:flutter/material.dart';
import 'app_i18n.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'automatic_live_screen.dart';
import 'iptv_sources_screen.dart';

import 'fantasy_screen.dart';
import 'news_screen.dart';
import 'notification_service.dart';
import 'public_chat_screen.dart';
import 'sports_api_service.dart';
import 'sportsapi_statistics_screen.dart';
import 'sports_summaries_screen.dart';
import 'marca_agenda_screen.dart';

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

const String contactUrl = 'https://wa.me/5927214741';
const String settingsPhotoAsset =
    'assets/images/file_000000006048820e9e0720f1adf548f1.png';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    final message = details.exceptionAsString();
    final visibleMessage = message.length > 180
        ? '${message.substring(0, 177)}…'
        : message;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: appBg,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, color: appPink, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudo mostrar esta sección',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    visibleMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: appMuted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };
  try {
    final prefs = await SharedPreferences.getInstance();
    appLanguage.value = parseLanguage(prefs.getString('app_language'));
    telegramLink.value = prefs.getString('telegram_public_link') ?? '';
    final savedApiUrl = prefs.getString('sports_api_base_url');
    sportsApiBaseUrl.value =
        SportsApiService.normalizeBaseUrl(savedApiUrl ?? '') ??
        defaultSportsApiBaseUrl;
  } catch (_) {
    // La app puede abrirse aunque el almacenamiento local no esté disponible.
  }
  try {
    await NotificationService.initialize();
  } catch (_) {
    // La app continúa funcionando aunque el dispositivo no admita avisos.
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
        locale: Locale(languageCode(language)),
        supportedLocales: const <Locale>[
          Locale('es'), Locale('en'), Locale('pt'), Locale('fr'),
        ],
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
  @override
  void initState() {
    super.initState();
    NotificationService.liveEventNotification.addListener(_handleLivePush);
    if (NotificationService.liveEventNotification.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleLivePush());
    }
  }

  void _handleLivePush() {
    final eventId = NotificationService.liveEventNotification.value;
    if (eventId == null || !mounted) return;
    NotificationService.liveEventNotification.value = null;
    _selectTab(_liveTab);
  }

  @override
  void dispose() {
    NotificationService.liveEventNotification.removeListener(_handleLivePush);
    super.dispose();
  }

  static const int _homeTab = 0;
  static const int _liveTab = 1;
  static const int _agendaTab = 2;
  static const int _newsTab = 3;
  static const int _fantasyTab = 4;
  static const int _statisticsTab = 5;
  static const int _summariesTab = 6;
  static const int _settingsTab = 7;

  int _selectedIndex = _homeTab;
  String _selectedStatisticsSport = 'Fútbol';
  bool _handlingBack = false;
  final Set<int> _visitedTabs = <int>{_homeTab};

  void _selectTab(int index) {
    if (index < _homeTab || index > _settingsTab) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  void _selectSport(String sport) {
    setState(() {
      _selectedStatisticsSport = sport;
      _selectedIndex = _statisticsTab;
      _visitedTabs.add(_statisticsTab);
    });
  }

  void _openStatistics() => _selectTab(_statisticsTab);

  void _openWebAgenda() => _selectTab(_agendaTab);

  Future<void> _openPublicChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PublicChatScreen()),
    );
  }

  void _openFantasy() => _selectTab(_fantasyTab);

  Future<void> _openDonations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DonationsScreen()),
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
          title: Text(
            appText('Canal de Telegram', 'Telegram channel', 'Canal do Telegram', 'Canal Telegram'),
            style: const TextStyle(color: appCyan, fontWeight: FontWeight.w900),
          ),
          content: Text(
            appText(
              'Este espacio queda reservado para tu canal. Todavía no hay un enlace público configurado; no abriremos uno genérico.',
              'This space is reserved for your channel. No public link is configured yet; we will not open a generic or invented one.',
              'Este espaço está reservado para seu canal. Ainda não há um link público configurado; não abriremos um link genérico ou inventado.',
              'Cet espace est réservé à votre chaîne. Aucun lien public n’est encore configuré ; aucun lien générique ou inventé ne sera ouvert.'),
            style: const TextStyle(color: appMuted, height: 1.45),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(appText('Cerrar', 'Close', 'Fechar', 'Fermer')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _selectTab(_settingsTab);
              },
              child: Text(appText('Configurar enlace', 'Set link', 'Configurar link', 'Configurer le lien')),
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
      if (_selectedIndex != _homeTab) {
        if (mounted) setState(() => _selectedIndex = _homeTab);
        return;
      }
      if (!mounted) return;
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: appPanel,
          title: const Text(
            'Salir de Deporte Total 360°',
            style: TextStyle(color: appCyan, fontWeight: FontWeight.w900),
          ),
          content: Text(
            appText(
              '¿Quieres cerrar la aplicación?',
              'Do you want to close the app?',
              'Deseja fechar o aplicativo?',
              'Voulez-vous fermer l’application?',
            ),
            style: const TextStyle(color: appMuted),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(appText('Cancelar', 'Cancel', 'Cancelar', 'Annuler')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(appText('Salir', 'Exit', 'Sair', 'Quitter')),
            ),
          ],
        ),
      );
      if (shouldExit == true) await SystemNavigator.pop();
    } finally {
      _handlingBack = false;
    }
  }

  Widget _buildBottomTab(int index, IconData icon, String label, Color accent) {
    final selected = _selectedIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => _selectTab(index),
        child: SizedBox(
          width: 82,
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: selected ? accent : appMuted),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? accent : appMuted,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeDashboard(
        onNavigate: _selectTab,
        onSportSelected: _selectSport,
        onTelegram: _openTelegram,
        onContact: () => openExternalLink(context, contactUrl, label: 'WhatsApp'),
        onDonations: _openDonations,
        onFantasy: _openFantasy,
        onStatistics: _openStatistics,
        onOpenAgenda: _openWebAgenda,
        onChat: _openPublicChat,
      ),
      AutomaticLiveScreen(
        onOpenAgenda: () => _selectTab(_agendaTab),
        isActive: _selectedIndex == _liveTab,
      ),
      _visitedTabs.contains(_agendaTab)
          ? MarcaAgendaScreen(
              isActive: _selectedIndex == _agendaTab,
              onOpenLive: () => _selectTab(_liveTab),
            )
          : const SizedBox.shrink(),
      _visitedTabs.contains(_newsTab) ? const NewsScreen() : const SizedBox.shrink(),
      _visitedTabs.contains(_fantasyTab) ? const FantasyScreen() : const SizedBox.shrink(),
      _visitedTabs.contains(_statisticsTab)
          ? SportsApiStatisticsScreen(
              key: ValueKey<String>('statistics-${_selectedStatisticsSport}'),
              initialSport: _selectedStatisticsSport,
              onOpenAgenda: () => _selectTab(_agendaTab),
            )
          : const SizedBox.shrink(),
      _visitedTabs.contains(_summariesTab)
          ? const SportsSummariesScreen()
          : const SizedBox.shrink(),
      _visitedTabs.contains(_settingsTab) ? const SettingsScreen() : const SizedBox.shrink(),
    ];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: appBg,
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020B19),
            border: const Border(top: BorderSide(color: appLine)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: appCyan.withAlpha(18), blurRadius: 18, offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _buildBottomTab(_homeTab, Icons.home_rounded, tr('home'), appCyan),
                  _buildBottomTab(_liveTab, Icons.live_tv_rounded, 'Deportes en vivo', appPink),
                  _buildBottomTab(_agendaTab, Icons.calendar_month_rounded, 'Agenda de hoy', appGreen),
                  _buildBottomTab(_newsTab, Icons.article_rounded, tr('news'), appGreen),
                  _buildBottomTab(_fantasyTab, Icons.emoji_events_rounded, 'Mister Fantasy', appYellow),
                  _buildBottomTab(_statisticsTab, Icons.query_stats_rounded, tr('statistics'), appCyan),
                  _buildBottomTab(_summariesTab, Icons.play_circle_fill_rounded,
                    appText('Resúmenes', 'Highlights', 'Resumos', 'Résumés'), appPink),
                  _buildBottomTab(_settingsTab, Icons.settings_rounded, tr('settings'), appCyan),
                ],
              ),
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
    required this.onStatistics,
    required this.onOpenAgenda,
    required this.onChat,
  });

  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onSportSelected;
  final VoidCallback onTelegram;
  final VoidCallback onContact;
  final VoidCallback onDonations;
  final VoidCallback onFantasy;
  final VoidCallback onStatistics;
  final VoidCallback onOpenAgenda;
  final VoidCallback onChat;

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
            tooltip: tr('stats_title'),
            onPressed: onStatistics,
            icon: const Icon(Icons.query_stats_rounded, color: appGreen),
          ),
          IconButton(
            tooltip: tr('settings'),
            onPressed: () => onNavigate(7),
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SectionHeading(
                        title: appText(
                          'TODOS LOS DEPORTES',
                          'ALL SPORTS',
                          'TODOS OS ESPORTES',
                          'TOUS LES SPORTS',
                        ),
                        icon: Icons.public_rounded,
                      ),
                    ),
                    TextButton(
                      onPressed: onStatistics,
                      child: Text(
                        appText(
                          'Explorar →',
                          'Explore →',
                          'Explorar →',
                          'Explorer →',
                        ),
                        style: const TextStyle(color: appCyan, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _SportTile(
                      title: 'FÚTBOL',
                      subtitle: 'LaLiga • Premier • Champions',
                      icon: Icons.sports_soccer_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Fútbol'),
                    ),
                    _SportTile(
                      title: 'BALONCESTO',
                      subtitle: 'NBA • WNBA • FIBA',
                      icon: Icons.sports_basketball_rounded,
                      color: appYellow,
                      onTap: () => onSportSelected('Baloncesto'),
                    ),
                    _SportTile(
                      title: 'BÉISBOL',
                      subtitle: 'MLB • WBC • WBSC',
                      icon: Icons.sports_baseball_rounded,
                      color: appPink,
                      onTap: () => onSportSelected('Béisbol'),
                    ),
                    _SportTile(
                      title: 'HOCKEY',
                      subtitle: 'NHL • PWHL • IIHF',
                      icon: Icons.sports_hockey_rounded,
                      color: appCyan,
                      onTap: () => onSportSelected('Hockey sobre hielo'),
                    ),
                    _SportTile(
                      title: 'VOLEIBOL',
                      subtitle: 'VNL • FIVB',
                      icon: Icons.sports_volleyball_rounded,
                      color: appBlue,
                      onTap: () => onSportSelected('Voleibol'),
                    ),
                    _SportTile(
                      title: 'MMA',
                      subtitle: 'UFC • Combates',
                      icon: Icons.sports_mma_rounded,
                      color: appPink,
                      onTap: () => onSportSelected('MMA'),
                    ),
                    _SportTile(
                      title: 'FÚTBOL SALA',
                      subtitle: 'Mundiales • Copas',
                      icon: Icons.sports_soccer_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Fútbol sala'),
                    ),
                    _SportTile(
                      title: 'CICLISMO',
                      subtitle: 'Tour • Giro • Vuelta',
                      icon: Icons.directions_bike_rounded,
                      color: appYellow,
                      onTap: () => onSportSelected('Ciclismo'),
                    ),
                    _SportTile(
                      title: 'DEPORTES DE MOTOR',
                      subtitle: 'F1 • MotoGP',
                      icon: Icons.sports_motorsports_rounded,
                      color: appBlue,
                      onTap: () => onSportSelected('Deportes de motor'),
                    ),
                    _SportTile(
                      title: 'BALONMANO',
                      subtitle: 'IHF • EHF',
                      icon: Icons.sports_handball_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Balonmano'),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                _SectionHeading(
                  title: appText(
                    'ACCESO RÁPIDO',
                    'QUICK ACCESS',
                    'ACESSO RÁPIDO',
                    'ACCÈS RAPIDE',
                  ),
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: tr('streams'),
                  subtitle: appText(
                    'Canales deportivos y reproducción multivista',
                    'Sports channels and multi-view playback',
                    'Canais esportivos e reprodução multivista',
                    'Chaînes sportives et lecture multivue',
                  ),
                  icon: Icons.live_tv_rounded,
                  color: appRed,
                  onTap: () => onNavigate(1),
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: tr('matches'),
                  subtitle: appText(
                    'Calendario deportivo, marcadores y filtros',
                    'Sports schedule, scores and filters',
                    'Calendário esportivo, placares e filtros',
                    'Calendrier sportif, scores et filtres',
                  ),
                  icon: Icons.calendar_month_rounded,
                  color: appGreen,
                  onTap: onOpenAgenda,
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: tr('telegram'),
                  subtitle: appText(
                    'Espacio reservado para tu canal oficial',
                    'Reserved space for your official channel',
                    'Espaço reservado para seu canal oficial',
                    'Espace réservé à votre chaîne officielle',
                  ),
                  icon: Icons.send_rounded,
                  color: appBlue,
                  onTap: onTelegram,
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: tr('statistics'),
                  subtitle: appText(
                    'Ligas, clasificaciones, pilotos y luchadores',
                    'Leagues, standings, drivers and fighters',
                    'Ligas, classificações, pilotos e lutadores',
                    'Ligues, classements, pilotes et combattants',
                  ),
                  icon: Icons.query_stats_rounded,
                  color: appCyan,
                  onTap: onStatistics,
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: tr('news'),
                  subtitle: appText(
                    'Noticias deportivas de varias fuentes RSS',
                    'Sports news from multiple RSS sources',
                    'Notícias esportivas de várias fontes RSS',
                    'Actualités sportives de plusieurs flux RSS',
                  ),
                  icon: Icons.article_rounded,
                  color: appYellow,
                  onTap: () => onNavigate(3),
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: appText('RESÚMENES', 'HIGHLIGHTS', 'RESUMOS', 'RÉSUMÉS'),
                  subtitle: appText(
                    'Goles, jugadas y vídeos deportivos',
                    'Goals, plays and sports videos',
                    'Gols, jogadas e vídeos esportivos',
                    'Buts, actions et vidéos sportives',
                  ),
                  icon: Icons.play_circle_fill_rounded,
                  color: appPink,
                  onTap: () => onNavigate(6),
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: 'FANTASY',
                  subtitle: appText(
                    'Abrir Mister Fantasy',
                    'Open Mister Fantasy',
                    'Abrir Mister Fantasy',
                    'Ouvrir Mister Fantasy',
                  ),
                  icon: Icons.emoji_events_rounded,
                  color: appPink,
                  onTap: onFantasy,
                ),
                const SizedBox(height: 8),
                _HomeActionCard(
                  title: tr('public_chat'),
                  subtitle: appText(
                    'Sala compartida para conversar con todos',
                    'Shared room to chat with everyone',
                    'Sala compartilhada para conversar com todos',
                    'Salon partagé pour discuter avec tous',
                  ),
                  icon: Icons.forum_rounded,
                  color: appCyan,
                  onTap: onChat,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ActionTile(
                        title: tr('contact'),
                        subtitle: appText(
                          'En caso de fallas',
                          'For support',
                          'Em caso de problemas',
                          'En cas de problème',
                        ),
                        icon: Icons.chat_rounded,
                        color: appGreen,
                        onTap: onContact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionTile(
                        title: tr('donations'),
                        subtitle: appText(
                          'Apoya el proyecto',
                          'Support the project',
                          'Apoie o projeto',
                          'Soutenir le projet',
                        ),
                        icon: Icons.favorite_rounded,
                        color: appYellow,
                        onTap: onDonations,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.sports_rounded, color: appPink, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              appText(
                                '¡EL DEPORTE NOS UNE!',
                                'SPORT BRINGS US TOGETHER!',
                                'O ESPORTE NOS UNE!',
                                'LE SPORT NOUS UNIT !',
                              ),
                              style: const TextStyle(
                                color: appCyan,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: .4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appText(
                                'Tu pasión, en todas partes.',
                                'Your passion, everywhere.',
                                'Sua paixão, em todos os lugares.',
                                'Votre passion, partout.',
                              ),
                              style: const TextStyle(color: appMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.bolt_rounded, color: appYellow, size: 27),
                    ],
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

class _HomeSportChip extends StatelessWidget {
  const _HomeSportChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withAlpha(130)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: onTap == null ? appMuted : Colors.white,
                  fontSize: 9,
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

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
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
  Widget build(BuildContext context) {
    return Material(
      color: appPanel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[color.withAlpha(34), appPanel],
            ),
            border: Border.all(color: color.withAlpha(190)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withAlpha(22), blurRadius: 13),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 29),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: appMuted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 23),
            ],
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
      height: 148,
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
        'assets/images/app_icon.png',
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



class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _telegramController;
  bool _saving = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _telegramController = TextEditingController(text: telegramLink.value);
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? false);
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(
            'Activa el permiso de notificaciones en Android.',
            'Enable notification permission in Android settings.',
            'Ative a permissão de notificações nas configurações do Android.',
            'Activez l’autorisation des notifications dans les paramètres Android.'))));
        return;
      }
    } else {
      await NotificationService.cancelMatchReminders();
      await NotificationService.unregisterCurrentDevice();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (_) {}
    if (enabled) await NotificationService.registerCurrentDevice();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService.showTestNotification();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _telegramController.dispose();
    super.dispose();
  }

  int _signatureTapCount = 0;
  DateTime? _lastSignatureTapAt;

  void _handleSignatureTap() {
    final now = DateTime.now();
    final lastTap = _lastSignatureTapAt;
    if (lastTap == null || now.difference(lastTap) > const Duration(seconds: 3)) {
      _signatureTapCount = 0;
    }
    _lastSignatureTapAt = now;
    _signatureTapCount++;

    if (_signatureTapCount >= 10) {
      _signatureTapCount = 0;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const DeveloperSettingsScreen(),
        ),
      );
    }
  }

  Future<void> _save() async {
    final link = _telegramController.text.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null ||
          uri.scheme != 'https' ||
          (uri.host != 't.me' && uri.host != 'telegram.me')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usa el enlace público real https://t.me/tu_canal.')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('telegram_public_link', link);
      telegramLink.value = link;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar. Vuelve a intentarlo.')),
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
                  Expanded(
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
                          tr('settings_description'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleSignatureTap,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'DAMIAN.APK',
                              style: TextStyle(
                                color: appPink,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('settings_intro'),
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
                  Text(
                    tr('language'),
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
                  const SizedBox(height: 14),
                  Text(
                    tr('notifications'),
                    style: const TextStyle(
                      color: appCyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr('notifications_description'),
                    style: const TextStyle(
                      color: appMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        tr('notifications_enabled'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        appText(
                          'Aviso antes de los eventos que cargues en la agenda.',
                          'Reminder before events you load in the schedule.',
                          'Aviso antes dos eventos carregados na agenda.',
                          'Alerte avant les événements chargés dans le calendrier.',
                        ),
                        style: const TextStyle(color: appMuted, fontSize: 10),
                      ),
                      value: _notificationsEnabled,
                      activeThumbColor: appGreen,
                      onChanged: _toggleNotifications,
                    ),
                  ),
                  if (_notificationsEnabled)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _testNotification,
                        icon: const Icon(Icons.notifications_active_rounded),
                        label: Text(appText(
                          'Probar notificación',
                          'Test notification',
                          'Testar notificação',
                          'Tester la notification',
                        )),
                      ),
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
                  Text(
                    tr('telegram_section').toUpperCase(),
                    style: TextStyle(
                      color: appCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('telegram_description'),
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
                    decoration: InputDecoration(
                      labelText: tr('public_link'),
                      hintText: 'https://t.me/tu_canal',
                      prefixIcon: Icon(Icons.send_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _saving
                            ? appText('GUARDANDO…', 'SAVING…', 'SALVANDO…', 'ENREGISTREMENT…')
                            : appText('GUARDAR CONFIGURACIÓN', 'SAVE SETTINGS', 'SALVAR CONFIGURAÇÃO', 'ENREGISTRER LES PARAMÈTRES'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: appBg,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

          ],
        ),
      ),
    );
  }
}


class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  late final TextEditingController _apiUrlController;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: sportsApiBaseUrl.value);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _testConnection() async {
    final url = SportsApiService.normalizeBaseUrl(_apiUrlController.text);
    if (url == null) {
      _showMessage(appText('Introduce una URL HTTPS válida del Worker.', 'Enter a valid HTTPS Worker URL.', 'Digite uma URL HTTPS válida do Worker.', 'Saisissez une URL HTTPS valide du Worker.'));
      return;
    }
    setState(() => _testing = true);
    try {
      await SportsApiService().checkHealth(url);
      _showMessage('Worker operativo. API-Sports queda disponible únicamente para Estadísticas.');
    } catch (error) {
      _showMessage('La prueba del servicio de estadísticas falló: $error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveApiUrl() async {
    final url = SportsApiService.normalizeBaseUrl(_apiUrlController.text);
    if (url == null) {
      _showMessage('Introduce una URL HTTPS válida del Worker.');
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sports_api_base_url', url);
      sportsApiBaseUrl.value = url;
      _apiUrlController.text = url;
      _showMessage(appText('Dirección de la API guardada.', 'API address saved.', 'Endereço da API salvo.', 'Adresse de l’API enregistrée.'));
    } catch (_) {
      _showMessage(appText('No se pudo guardar la dirección. Inténtalo de nuevo.', 'Could not save the address. Try again.', 'Não foi possível salvar o endereço. Tente novamente.', 'Impossible d’enregistrer l’adresse. Réessayez.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearApiUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sports_api_base_url');
      sportsApiBaseUrl.value = '';
      _apiUrlController.clear();
      _showMessage(appText('Dirección de la API eliminada.', 'API address cleared.', 'Endereço da API removido.', 'Adresse de l’API supprimée.'));
    } catch (_) {
      _showMessage(appText('No se pudo eliminar la dirección guardada.', 'Could not clear the saved address.', 'Não foi possível remover o endereço salvo.', 'Impossible d’effacer l’adresse enregistrée.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg,
      appBar: AppBar(
        title: Text(
          appText('DAMIÁN APK · CENTRO IPTV', 'DAMIÁN APK · IPTV CONTROL', 'DAMIÁN APK · IPTV', 'DAMIÁN APK · IPTV'),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appPanel,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: appCyan.withAlpha(180)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.developer_mode_rounded, color: appCyan),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          appText('CONEXIÓN DEL SERVIDOR DEPORTIVO', 'SPORTS SERVER CONNECTION', 'CONEXÃO DO SERVIDOR ESPORTIVO', 'CONNEXION AU SERVEUR SPORTIF'),
                          style: TextStyle(
                            color: appCyan,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appText('Introduce la dirección HTTPS pública del Cloudflare Worker. No pegues aquí la clave de API.', 'Enter the public HTTPS URL of your Cloudflare Worker. Do not paste your API key here.', 'Digite o endereço HTTPS público do Cloudflare Worker. Não cole sua chave de API aqui.', 'Saisissez l’URL HTTPS publique de votre Cloudflare Worker. Ne collez pas votre clé API ici.'),
                    style: TextStyle(color: appMuted, height: 1.5, fontSize: 12),
                  ),
                  const SizedBox(height: 13),
                  TextField(
                    controller: _apiUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: appText('URL del servidor API', 'API server URL', 'URL do servidor API', 'URL du serveur API'),
                      hintText: 'https://tu-worker.tu-cuenta.workers.dev',
                      prefixIcon: Icon(Icons.cloud_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded),
                      label: Text(_testing ? appText('COMPROBANDO…', 'CHECKING…', 'VERIFICANDO…', 'VÉRIFICATION…') : appText('PROBAR CONEXIÓN', 'TEST CONNECTION', 'TESTAR CONEXÃO', 'TESTER LA CONNEXION')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appCyan,
                        side: const BorderSide(color: appCyan),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveApiUrl,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? appText('GUARDANDO…', 'SAVING…', 'SALVANDO…', 'ENREGISTREMENT…') : appText('GUARDAR SERVIDOR', 'SAVE SERVER', 'SALVAR SERVIDOR', 'ENREGISTRER LE SERVEUR')),
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: appBg,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearApiUrl,
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      label: Text(appText('Borrar dirección guardada', 'Clear saved address', 'Apagar endereço salvo', 'Effacer l’adresse enregistrée')),
                      style: TextButton.styleFrom(foregroundColor: appPink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appPanel,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: appPink.withAlpha(180)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: <Widget>[
                    const Icon(Icons.auto_awesome_rounded, color: appPink),
                    SizedBox(width: 9),
                    Expanded(child: Text(
                      'CENTRO DE LISTAS Y CANALES IPTV',
                      style: TextStyle(color: appPink, fontWeight: FontWeight.w900, fontSize: 12),
                    )),
                  ]),
                  SizedBox(height: 9),
                  Text(
                    'Administra tus propias listas M3U/M3U8 y guías EPG/XMLTV. Combina varias fuentes, consulta el catálogo unificado, busca canales, revisa sus alternativas y conserva los ocho reproductores de Deporte Total 360°. Pega varias direcciones de una vez, una por línea.',
                    style: TextStyle(color: appMuted, fontSize: 11, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const IptvSourcesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('GESTIONAR LISTAS IPTV Y EPG'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appCyan,
                        side: const BorderSide(color: appCyan),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appPanel2,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: appGreen.withAlpha(150)),
              ),
              child: Text(
                appText('SEGURIDAD: la clave APISPORTS_KEY permanece como secreto del Worker en Cloudflare. La aplicación guarda solo la URL pública. El acceso directo desde Ajustes y el atajo de diez toques abren esta misma pantalla; ninguno sustituye autenticación real.', 'SECURITY: APISPORTS_KEY remains a Cloudflare Worker secret. The app stores only the public URL. The Settings shortcut and the ten-tap shortcut open this same screen; neither replaces real authentication.', 'SEGURANÇA: APISPORTS_KEY permanece como segredo do Worker no Cloudflare. O app salva apenas a URL pública. O atalho em Configurações e o atalho de dez toques abrem esta mesma tela; nenhum substitui autenticação real.', 'SÉCURITÉ : APISPORTS_KEY reste un secret du Worker Cloudflare. L’application ne conserve que l’URL publique. Le raccourci des paramètres et celui de dix pressions ouvrent le même écran ; aucun ne remplace une véritable authentification.'),
                style: TextStyle(color: appMuted, fontSize: 11, height: 1.5),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.favorite_rounded, color: appPink, size: 56),
                    SizedBox(height: 13),
                    Text(
                      appText('GRACIAS POR APOYAR', 'THANK YOU FOR SUPPORTING US', 'OBRIGADO POR APOIAR', 'MERCI DE VOTRE SOUTIEN'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appCyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      appText('Tu apoyo ayuda a mantener y mejorar Deporte Total 360°. El cobro todavía no está conectado; no se realizará ningún pago desde esta pantalla.', 'Your support helps maintain and improve Deporte Total 360°. Payments are not connected yet; this screen will not charge you.', 'Seu apoio ajuda a manter e melhorar o Deporte Total 360°. O pagamento ainda não está conectado; nenhuma cobrança será feita nesta tela.', 'Votre soutien aide à maintenir et améliorer Deporte Total 360°. Le paiement n’est pas encore connecté ; aucun paiement ne sera effectué depuis cet écran.'),
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
