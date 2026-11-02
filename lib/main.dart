import 'dart:async';
import 'package:flutter/material.dart';
import 'app_i18n.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'agenda_screen.dart';
import 'channel_catalog_screen.dart';
import 'multi_match_player_screen.dart';
import 'fantasy_screen.dart';
import 'news_screen.dart';
import 'notification_service.dart';
import 'public_chat_screen.dart';
import 'sports_api_service.dart';
import 'sports_statistics_screen.dart';
import 'sports_summaries_screen.dart';
import 'sports_community_screen.dart';
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
String buildRtmpUrl(String channel) => '$rtmpBase$channel';
String buildHlsUrl(String channel) => '$hlsBase$channel/playlist.m3u8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Presenta Inicio antes de consultar plugins. Un servicio lento o no
  // disponible nunca debe dejar la ventana nativa en blanco.
  runApp(const DeporteTotal360App());

  // Preferencias y avisos se preparan después del primer frame.
  unawaited(_initializeAppServices());
}

Future<void> _initializeAppServices() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    appLanguage.value = parseLanguage(prefs.getString('app_language'));
    final savedChannel = prefs.getString('ssh101_channel')?.trim();
    channelSlug.value = savedChannel == null || savedChannel.isEmpty
        ? defaultSsh101Channel
        : savedChannel;
    telegramLink.value = prefs.getString('telegram_public_link') ?? '';
    final savedApiUrl = prefs.getString('sports_api_base_url');
    sportsApiBaseUrl.value =
        SportsApiService.normalizeBaseUrl(savedApiUrl ?? '') ??
        defaultSportsApiBaseUrl;
  } catch (_) {
    // El Inicio conserva valores seguros aunque no esté disponible el almacenamiento.
  }

  try {
    await NotificationService.initialize();
  } catch (_) {
    // Las notificaciones son opcionales y no bloquean el resto de la app.
  }
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
  static const int _homeTab = 0;
  static const int _feedTab = 1;
  static const int _notificationsTab = 2;
  static const int _statisticsTab = 3;
  static const int _liveTab = 4;
  static const int _agendaWebTab = 5;
  static const int _nativeAgendaTab = 6;
  static const int _newsTab = 7;
  static const int _summariesTab = 8;
  static const int _fantasyTab = 9;
  static const int _chatTab = 10;
  static const int _channelsTab = 11;
  static const int _settingsTab = 12;

  final GlobalKey<WebAgendaScreenState> _webAgendaKey =
      GlobalKey<WebAgendaScreenState>();

  int _selectedIndex = _homeTab;
  final List<bool> _initializedTabs = <bool>[
    true, false, false, false, false, false, false, false, false, false, false,
    false, false,
  ];
  String _selectedStatisticsSport = 'Fútbol';
  bool _handlingBack = false;

  void _selectTab(int index) {
    if (index < 0 || index > _notificationsTab) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _selectSport(String sport) {
    setState(() {
      _selectedStatisticsSport = sport;
      _selectedIndex = _statisticsTab;
    });
  }

  Widget _tabButton(int index, IconData icon, String label, Color accent) {
    final selected = _selectedIndex == index;
    return SizedBox(
      key: ValueKey<String>('bottom-tab-$index'),
      width: 78,
      child: InkWell(
        onTap: () => _selectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.fromLTRB(3, 6, 3, 5),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent.withAlpha(180) : Colors.transparent,
            ),
            boxShadow: selected
                ? <BoxShadow>[BoxShadow(color: accent.withAlpha(28), blurRadius: 10)]
                : const <BoxShadow>[],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: selected ? accent : appMuted, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : appMuted,
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

  Future<void> _openStatistics() async {
    _selectTab(_statisticsTab);
  }

  void _openAgenda() => _selectTab(_nativeAgendaTab);

  Future<void> _openMultiMatchView(List<MatchEvent> matches) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MultiMatchPlayerScreen(matches: matches),
      ),
    );
  }

  Future<void> _openChannelCatalog() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ChannelCatalogSettingsScreen(),
      ),
    );
  }

  void _openEmbeddedWebAgenda() => _selectTab(_agendaWebTab);

  void _openPublicChat() => _selectTab(_chatTab);

  void _openFantasy() => _selectTab(_fantasyTab);

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
          title: Text(
            appText('Canal de Telegram', 'Telegram channel', 'Canal do Telegram', 'Canal Telegram'),
            style: TextStyle(color: appCyan, fontWeight: FontWeight.w900),
          ),
          content: Text(
            appText(
              'Este espacio queda reservado para tu canal. Todavía no hay un enlace público configurado; no abriremos uno genérico.',
              'This space is reserved for your channel. No public link is configured yet; we will not open a generic or invented one.',
              'Este espaço está reservado para seu canal. Ainda não há um link público configurado; não abriremos um link genérico ou inventado.',
              'Cet espace est réservé à votre chaîne. Aucun lien public n’est encore configuré ; aucun lien générique ou inventé ne sera ouvert.'),
            style: TextStyle(color: appMuted, height: 1.45),
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

  Widget _buildTab(int index) {
    switch (index) {
      case _homeTab:
        return HomeDashboard(
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
          onStatistics: _openStatistics,
          onOpenAgenda: _openAgenda,
          onChat: _openPublicChat,
        );
      case _statisticsTab:
        return SportsStatisticsScreen(
          key: ValueKey<String>('statistics-$_selectedStatisticsSport'),
          initialSport: _selectedStatisticsSport,
          onOpenAgenda: _openAgenda,
        );
      case _liveTab:
        return LiveScreen(
          onOpenMultiView: _openMultiMatchView,
          onOpenChannelCatalog: _openChannelCatalog,
        );
      case _agendaWebTab:
        return WebAgendaScreen(
          key: _webAgendaKey,
          onExit: () => _selectTab(_nativeAgendaTab),
          onOpenLive: () => _selectTab(_liveTab),
        );
      case _nativeAgendaTab:
        return AgendaScreen(
          initialSport: 'Todos',
          onOpenWebAgenda: _openEmbeddedWebAgenda,
          onOpenMultiView: _openMultiMatchView,
          onOpenChannelCatalog: _openChannelCatalog,
        );
      case _newsTab:
        return const NewsScreen();
      case _summariesTab:
        return SportsSummariesScreen(isActive: _selectedIndex == _summariesTab);
      case _fantasyTab:
        return FantasyScreen(onExit: () => _selectTab(_homeTab));
      case _chatTab:
        return PublicChatScreen(isActive: _selectedIndex == _chatTab);
      case _channelsTab:
        return const ChannelCatalogScreen();
      case _settingsTab:
        return const SettingsScreen();
      case _feedTab:
        return SportsFeedScreen(
          onOpenLive: () => _selectTab(_liveTab),
          onOpenAgenda: () => _selectTab(_nativeAgendaTab),
          onOpenNews: () => _selectTab(_newsTab),
          onOpenSummaries: () => _selectTab(_summariesTab),
          onOpenChat: () => _selectTab(_chatTab),
        );
      case _notificationsTab:
        return SportsNotificationsScreen(
          onOpenAgenda: () => _selectTab(_nativeAgendaTab),
          onOpenLive: () => _selectTab(_liveTab),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(13, (index) {
      if (index == _selectedIndex) {
        _initializedTabs[index] = true;
      }
      if (!_initializedTabs[index]) {
        return const SizedBox.shrink();
      }
      // Los WebViews ocultos consumen memoria. Android puede destruir su
      // renderizador; los recreamos al volver a seleccionar cada sección.
      if (index != _selectedIndex &&
          (index == _agendaWebTab || index == _fantasyTab)) {
        return const SizedBox.shrink();
      }
      return _buildTab(index);
    }, growable: false);

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
          height: 66,
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _tabButton(_homeTab, Icons.home_rounded, tr('home'), appCyan),
                  _tabButton(_feedTab, Icons.dynamic_feed_rounded, 'Feed', appGreen),
                  _tabButton(_notificationsTab, Icons.notifications_active_rounded, 'Notificaciones', appYellow),
                  _tabButton(_statisticsTab, Icons.query_stats_rounded, tr('statistics'), appCyan),
                  _tabButton(_liveTab, Icons.live_tv_rounded, tr('live'), appPink),
                  _tabButton(_agendaWebTab, Icons.public_rounded, 'Fútbol Libre', appGreen),
                  _tabButton(_nativeAgendaTab, Icons.calendar_month_rounded, 'Partidos', appYellow),
                  _tabButton(_newsTab, Icons.article_rounded, tr('news'), appGreen),
                  _tabButton(_summariesTab, Icons.play_circle_fill_rounded,
                      appText('Resúmenes', 'Highlights', 'Resumos', 'Résumés'), appPink),
                  _tabButton(_fantasyTab, Icons.emoji_events_rounded, 'Fantasy', appYellow),
                  _tabButton(_chatTab, Icons.forum_rounded, 'Chat', appCyan),
                  _tabButton(_channelsTab, Icons.live_tv_rounded, 'Canales TV', appGreen),
                  _tabButton(_settingsTab, Icons.settings_rounded, tr('settings'), appCyan),
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
            onPressed: () => onNavigate(12),
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
                      title: appText('FÚTBOL', 'FOOTBALL', 'FUTEBOL', 'FOOTBALL'),
                      subtitle: appText(
                        'Ligas • Copas',
                        'Leagues • Cups',
                        'Ligas • Copas',
                        'Ligues • Coupes',
                      ),
                      icon: Icons.sports_soccer_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Fútbol'),
                    ),
                    _SportTile(
                      title: appText('BÁSQUET', 'BASKETBALL', 'BASQUETE', 'BASKET-BALL'),
                      subtitle: 'NBA • FIBA',
                      icon: Icons.sports_basketball_rounded,
                      color: appYellow,
                      onTap: () => onSportSelected('Básquet'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.23,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _SportTile(
                      title: appText('BÉISBOL', 'BASEBALL', 'BEISEBOL', 'BASEBALL'),
                      subtitle: 'MLB • Ligas',
                      icon: Icons.sports_baseball_rounded,
                      color: appPink,
                      onTap: () => onSportSelected('Béisbol'),
                    ),
                    _SportTile(
                      title: appText('VÓLEY', 'VOLLEYBALL', 'VÔLEI', 'VOLLEY-BALL'),
                      subtitle: 'Ligas • Torneos',
                      icon: Icons.sports_volleyball_rounded,
                      color: appBlue,
                      onTap: () => onSportSelected('Vóley'),
                    ),
                    _SportTile(
                      title: 'RUGBY',
                      subtitle: appText(
                        'Ligas • Torneos',
                        'Leagues • Tournaments',
                        'Ligas • Torneios',
                        'Ligues • Tournois',
                      ),
                      icon: Icons.sports_rugby_rounded,
                      color: appGreen,
                      onTap: () => onSportSelected('Rugby'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: appPanel,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: appCyan.withAlpha(135)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: appBlue.withAlpha(18), blurRadius: 15),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.sports_rounded, color: appPink, size: 19),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              appText(
                                'OTROS DEPORTES',
                                'MORE SPORTS',
                                'OUTROS ESPORTES',
                                'AUTRES SPORTS',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ),
                          Text(
                            'API-Sports',
                            style: TextStyle(color: appMuted, fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: <Widget>[
                          _HomeSportChip(
                            label: 'NBA',
                            icon: Icons.sports_basketball_rounded,
                            color: appYellow,
                            onTap: () => onSportSelected('NBA'),
                          ),
                          _HomeSportChip(
                            label: 'HOCKEY',
                            icon: Icons.sports_hockey_rounded,
                            color: appCyan,
                            onTap: () => onSportSelected('Hockey sobre hielo'),
                          ),
                          _HomeSportChip(
                            label: 'NFL',
                            icon: Icons.sports_football_rounded,
                            color: appPink,
                            onTap: () => onSportSelected('Fútbol americano'),
                          ),
                          _HomeSportChip(
                            label: appText('BALONMANO', 'HANDBALL', 'HANDEBOL', 'HANDBALL'),
                            icon: Icons.sports_handball_rounded,
                            color: appGreen,
                            onTap: () => onSportSelected('Balonmano'),
                          ),
                          _HomeSportChip(
                            label: 'FÚTBOL AUSTRALIANO',
                            icon: Icons.sports_football_rounded,
                            color: appBlue,
                            onTap: () => onSportSelected('Fútbol australiano'),
                          ),
                          _HomeSportChip(
                            label: 'FÓRMULA 1',
                            icon: Icons.sports_motorsports_rounded,
                            color: appYellow,
                            onTap: () => onSportSelected('Fórmula 1'),
                          ),
                          _HomeSportChip(
                            label: 'MMA',
                            icon: Icons.sports_mma_rounded,
                            color: appPink,
                            onTap: () => onSportSelected('MMA'),
                          ),
                          _HomeSportChip(
                            label: appText('TENIS · PRÓXIMAMENTE', 'TENNIS · COMING SOON', 'TÊNIS · EM BREVE', 'TENNIS · BIENTÔT'),
                            icon: Icons.sports_tennis_rounded,
                            color: appMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appText(
                          'Los deportes disponibles abren sus datos y estadísticas. Tenis se muestra como próximamente porque el servidor actual no ofrece todavía ese endpoint.',
                          'Available sports open their data and statistics. Tennis is marked as coming soon because the current server does not yet provide that endpoint.',
                          'Os esportes disponíveis abrem seus dados e estatísticas. Tênis aparece como em breve porque o servidor ainda não oferece esse endpoint.',
                          'Les sports disponibles ouvrent leurs données et statistiques. Le tennis est indiqué comme bientôt disponible car le serveur ne propose pas encore cet endpoint.',
                        ),
                        style: const TextStyle(
                          color: appMuted,
                          fontSize: 9,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
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
                    'Ver canales y abrir el reproductor SSH101',
                    'Watch channels and open the SSH101 player',
                    'Ver canais e abrir o player SSH101',
                    'Voir les chaînes et ouvrir le lecteur SSH101',
                  ),
                  icon: Icons.live_tv_rounded,
                  color: appRed,
                  onTap: () => onNavigate(4),
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
                  onTap: () => onNavigate(7),
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

class LiveScreen extends StatelessWidget {
  const LiveScreen({
    super.key,
    this.onOpenMultiView,
    this.onOpenChannelCatalog,
  });

  final ValueChanged<List<MatchEvent>>? onOpenMultiView;
  final VoidCallback? onOpenChannelCatalog;

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
    return AgendaScreen(
      initialSport: 'Todos',
      initialStatus: 'En vivo',
      onOpenPersonalChannel: () => _openPlayer(context),
      onOpenEncoder: () => _openEncoder(context),
      onOpenMultiView: onOpenMultiView,
      onOpenChannelCatalog: onOpenChannelCatalog,
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
        title: Text(
          appText('CONFIGURAR TRANSMISIÓN', 'STREAMING SETUP', 'CONFIGURAR TRANSMISSÃO', 'CONFIGURATION DU STREAM'),
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
            Text(
              appText(
                'Configura estas direcciones en tu encoder únicamente si corresponden a tu cuenta y canal activos.',
                'Use these encoder addresses only if they match your active account and channel.',
                'Use estes endereços no encoder somente se corresponderem à sua conta e canal ativos.',
                'Utilisez ces adresses dans votre encodeur uniquement si elles correspondent à votre compte et chaîne actifs.'),
              style: TextStyle(color: appMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            _CopyInfoCard(
              title: appText('Servidor RTMP', 'RTMP server', 'Servidor RTMP', 'Serveur RTMP'),
              value: rtmp,
              onCopy: () => _copy(context, rtmp),
            ),
            const SizedBox(height: 10),
            _CopyInfoCard(
              title: appText('URL HLS de reproducción', 'HLS playback URL', 'URL HLS de reprodução', 'URL de lecture HLS'),
              value: hls,
              onCopy: () => _copy(context, hls),
            ),
            const SizedBox(height: 16),
            Text(
              appText(
                'Si la señal no aparece, verifica el estado de tu canal y consulta la documentación. Estas direcciones no garantizan que exista una retransmisión activa.',
                'If the stream does not appear, check your channel status and service documentation. These addresses do not guarantee an active broadcast.',
                'Se o sinal não aparecer, verifique o status do canal e a documentação. Esses endereços não garantem uma transmissão ativa.',
                'Si le signal n’apparaît pas, vérifiez l’état de votre chaîne et la documentation. Ces adresses ne garantissent pas une diffusion active.'),
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
                label: Text(appText('Copiar', 'Copy', 'Copiar', 'Copier')),
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
        _error = appText(
            'El identificador del canal no es válido. Abre Ajustes y revísalo.',
            'The channel ID is invalid. Open Settings and check it.',
            'O ID do canal é inválido. Abra Configurações e verifique.',
            'L’identifiant de la chaîne est invalide. Ouvrez les paramètres et vérifiez-le.');
      });
      return;
    }
    final uri = Uri.tryParse(buildHlsUrl(slug));
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      setState(() {
        _loading = false;
        _error = appText('La dirección de reproducción no es válida.', 'The playback URL is invalid.', 'O endereço de reprodução é inválido.', 'L’adresse de lecture est invalide.');
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
    final controller = VideoPlayerController.networkUrl(
      uri,
      formatHint: VideoFormat.hls,
    );
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 25));
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) {
        await controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      setState(() {
        _loading = false;
        _error = appText(
            'No se pudo abrir el canal. Puede estar fuera de línea o no permitir esta conexión.',
            'The channel could not be opened. It may be offline or may not allow this connection.',
            'Não foi possível abrir o canal. Ele pode estar offline ou não permitir esta conexão.',
            'Impossible d’ouvrir la chaîne. Elle peut être hors ligne ou refuser cette connexion.');
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
        title: Text(
          appText('CANAL EN VIVO', 'LIVE CHANNEL', 'CANAL AO VIVO', 'CHAÎNE EN DIRECT'),
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
                                  label: Text(appText('Reintentar', 'Retry', 'Tentar novamente', 'Réessayer')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: appCyan,
                                    side: const BorderSide(color: appCyan),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : controller == null || !controller.value.isInitialized
                            ? Center(
                                child: Text(
                                  appText('El reproductor no está disponible.', 'The player is unavailable.', 'O player não está disponível.', 'Le lecteur n’est pas disponible.'),
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
                  controller.value.isPlaying ? appText('Pausar', 'Pause', 'Pausar', 'Pause') : appText('Reproducir', 'Play', 'Reproduzir', 'Lire'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: appBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              appText('Canal configurado: ${widget.channel}', 'Configured channel: ${widget.channel}', 'Canal configurado: ${widget.channel}', 'Chaîne configurée : ${widget.channel}'),
              style: const TextStyle(
                color: appCyan,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appText(
                'La reproducción depende de que el servidor entregue una señal compatible y que tengas permiso para acceder a ella.',
                'Playback depends on the server providing a compatible stream and your permission to access it.',
                'A reprodução depende de o servidor fornecer um sinal compatível e de você ter permissão para acessá-lo.',
                'La lecture dépend d’un signal compatible fourni par le serveur et de votre autorisation d’y accéder.'),
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
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _channelController = TextEditingController(text: channelSlug.value);
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
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (_) {}
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
    _channelController.dispose();
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
              border: appBlue,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x332D8CFF),
                    child: Icon(Icons.cloud_sync_rounded, color: appCyan),
                  ),
                  title: Text(
                    appText(
                      'Servidor de estadísticas y agenda',
                      'Statistics and schedule server',
                      'Servidor de estatísticas e agenda',
                      'Serveur des statistiques et du calendrier',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    appText(
                      'Comprobar la conexión y configurar la URL pública del Worker.',
                      'Check the connection and configure the public Worker URL.',
                      'Verifique a conexão e configure a URL pública do Worker.',
                      'Vérifier la connexion et configurer l’URL publique du Worker.',
                    ),
                    style: const TextStyle(color: appMuted, fontSize: 11, height: 1.4),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: appCyan),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeveloperSettingsScreen(),
                    ),
                  ),
                ),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            _settingsCard(
              border: appGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr('stream_config').toUpperCase(),
                    style: TextStyle(
                      color: appCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('stream_description'),
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
                    decoration: InputDecoration(
                      labelText: tr('channel_id'),
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
                        _saving ? tr('saving') : tr('save_config'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CopyInfoCard(
                    title: tr('rtmp_server'),
                    value: rtmp,
                    onCopy: () => _copy(rtmp),
                  ),
                  const SizedBox(height: 9),
                  _CopyInfoCard(
                    title: tr('hls_url'),
                    value: hls,
                    onCopy: () => _copy(hls),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Text(
              tr('stream_notice'),
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
      final service = SportsApiService();
      await service.checkHealth(url);
      final fixtureCount = await service.checkFootballFixtures(url);
      _showMessage(
        fixtureCount == 0
            ? appText(
                'Worker operativo y API-Sports configurada. La consulta respondió correctamente, pero no hay partidos en los próximos 7 días.',
                'Worker online and API-Sports configured. The fixture request succeeded, but there are no matches in the next 7 days.',
                'Worker online e API-Sports configurada. A consulta funcionou, mas não há jogos nos próximos 7 dias.',
                'Worker en ligne et API-Sports configurée. La requête a réussi, mais aucun match dans les 7 prochains jours.',
              )
            : appText(
                'Conexión verificada: $fixtureCount partidos recibidos en los próximos 7 días.',
                'Connection verified: $fixtureCount matches received in the next 7 days.',
                'Conexão verificada: $fixtureCount jogos recebidos nos próximos 7 dias.',
                'Connexion vérifiée : $fixtureCount matchs reçus dans les 7 prochains jours.',
              ),
      );
    } catch (error) {
      _showMessage(appText(
        'La prueba del servidor o de partidos falló: $error',
        'The server or fixtures test failed: $error',
        'O teste do servidor ou dos jogos falhou: $error',
        'Le test du serveur ou des matchs a échoué : $error',
      ));
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
          appText('SERVIDOR Y DATOS DEPORTIVOS', 'SPORTS DATA SERVER', 'SERVIDOR E DADOS ESPORTIVOS', 'SERVEUR ET DONNÉES SPORTIVES'),
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
