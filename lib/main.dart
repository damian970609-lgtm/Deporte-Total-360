import 'app_section_design.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_i18n.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'automatic_live_screen.dart';
import 'channel_catalog_screen.dart';
import 'channel_catalog_service.dart';

import 'fantasy_screen.dart';
import 'news_screen.dart';
import 'notification_service.dart';
import 'public_chat_screen.dart';
import 'sports_api_service.dart';
import 'sportsapi_statistics_screen.dart';
import 'sports_summaries_screen.dart';
import 'sports_agenda_screen.dart';

// Identidad visual unificada: blanco, negro, azul, rojo y verde neón.
const Color appBg = Color(0xFF000000);
const Color appPanel = Color(0xFF07090D);
const Color appPanel2 = Color(0xFF0D1118);
const Color appLine = Color(0xFF0047FF);
const Color appCyan = Color(0xFF00A3FF); // Alias histórico: azul neón.
const Color appBlue = Color(0xFF00A3FF);
const Color appPink = Color(0xFFFF1744); // Alias histórico: rojo neón.
const Color appGreen = Color(0xFF39FF14);
const Color appYellow = Color(0xFFFFFFFF); // Alias histórico: blanco.
const Color appRed = Color(0xFFFF1744);
const Color appMuted = Color(0xFFEAF0F8);

const String contactUrl = 'https://wa.me/5927214741';
const String settingsPhotoAsset =
    'assets/images/file_000000006048820e9e0720f1adf548f1.png';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(NotificationService.recordFlutterFatalError(details));
  };
  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Error no controlado en el isolate principal: $error');
    debugPrintStack(stackTrace: stackTrace);
    unawaited(NotificationService.recordFatalError(error, stackTrace));
    return true;
  };
  ErrorWidget.builder = (details) {
    final message = details.exceptionAsString();
    final contextDescription = details.context?.toDescription() ?? '';
    final stack = details.stack?.toString() ?? '';
    final diagnostic = <String>[
      message,
      if (contextDescription.isNotEmpty)
        'Widget: ' + contextDescription,
      if (stack.isNotEmpty) 'Traza:\n' + stack,
    ].join('\n\n');
    final visibleMessage = message.length > 180
        ? '${message.substring(0, 177)}…'
        : message;
    final stackPreview = stack.isEmpty
        ? 'Flutter no proporcionó una traza para este error.'
        : stack.split('\n').take(12).join('\n');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: appBg,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
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
                  if (contextDescription.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Widget: ' + contextDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appCyan, fontSize: 10),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: appPanel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: appLine),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        stackPreview,
                        style: const TextStyle(
                          color: appMuted,
                          fontSize: 9,
                          height: 1.3,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: diagnostic));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('COPIAR DIAGNÓSTICO'),
                    style: TextButton.styleFrom(foregroundColor: appCyan),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };
  // Primero se muestra la interfaz; la inicialización de plugins no bloquea
  // ni impide el primer arranque de la aplicación.
  runApp(const DeporteTotal360App());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeAppServices());
  });
}

Future<void> _initializeAppServices() async {
  try {
    await NotificationService.initializeCrashlytics();
  } catch (error, stackTrace) {
    debugPrint('Crashlytics no está disponible: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    appLanguage.value = parseLanguage(prefs.getString('app_language'));
    telegramLink.value = prefs.getString('telegram_public_link') ?? '';
    final savedApiUrl = prefs.getString('sports_api_base_url');
    sportsApiBaseUrl.value =
        SportsApiService.normalizeBaseUrl(savedApiUrl ?? '') ??
        defaultSportsApiBaseUrl;
  } catch (error, stackTrace) {
    debugPrint('No se pudieron cargar las preferencias iniciales: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await NotificationService.initialize();
  } catch (error, stackTrace) {
    // Un fallo del plugin de notificaciones nunca debe impedir abrir Inicio.
    debugPrint('Las notificaciones no pudieron inicializarse: $error');
    debugPrintStack(stackTrace: stackTrace);
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
          Locale('es'), Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
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
          dividerColor: appLine,
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: appGreen,
            circularTrackColor: appPanel2,
            linearTrackColor: appPanel2,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: appCyan,
              foregroundColor: appBg,
              disabledBackgroundColor: appPanel2,
              disabledForegroundColor: appMuted,
              minimumSize: const Size(44, 44),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: .45,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: appCyan, width: .8),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: appPanel2,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(44, 44),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: appLine),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: appCyan,
              minimumSize: const Size(44, 44),
              side: const BorderSide(color: appCyan),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: appPanel2,
            contentTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        home: const AppAccessGate(),
      ),
    );
  }
}


/// Puerta de acceso comercial. La licencia se comprueba en el servidor
/// contra la cuenta Google verificada: una copia del APK no transfiere acceso.
class AppAccessGate extends StatefulWidget {
  const AppAccessGate({super.key});

  @override
  State<AppAccessGate> createState() => _AppAccessGateState();
}

enum _AccessGateStage { loading, signInRequired, denied, authorized, error }

class _AppAccessGateState extends State<AppAccessGate> {
  final ChannelCatalogService _licenseService = channelCatalogService;
  _AccessGateStage _stage = _AccessGateStage.loading;
  String? _email;
  String? _message;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreAndCheck());
  }

  Future<void> _prepareApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApiUrl = prefs.getString('sports_api_base_url');
    sportsApiBaseUrl.value =
        SportsApiService.normalizeBaseUrl(savedApiUrl ?? '') ??
        defaultSportsApiBaseUrl;
  }

  Future<void> _restoreAndCheck() async {
    if (mounted) {
      setState(() {
        _stage = _AccessGateStage.loading;
        _message = null;
      });
    }
    try {
      await _prepareApiSettings();
      final email = await _licenseService.restoreSession();
      if (!mounted) return;
      if (email == null) {
        setState(() => _stage = _AccessGateStage.signInRequired);
        return;
      }
      await _checkLicense(email);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _AccessGateStage.error;
        _message = error.toString();
      });
    }
  }

  Future<void> _checkLicense(String email) async {
    try {
      final license = await _licenseService.fetchAppLicenseStatus();
      if (!mounted) return;
      setState(() {
        _email = email;
        _stage = license.allowed
            ? _AccessGateStage.authorized
            : _AccessGateStage.denied;
        _message = license.allowed
            ? null
            : 'Esta cuenta todavía no tiene una licencia activa. '
                'Contacta con Damián para comprarla o solicitar un pase gratuito.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _AccessGateStage.error;
        _message = error.toString();
      });
    }
  }

  Future<void> _signIn() async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final email = await _licenseService.signIn();
      await _checkLicense(email);
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = _AccessGateStage.error;
          _message = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _changeAccount() async {
    setState(() {
      _working = true;
      _stage = _AccessGateStage.signInRequired;
      _email = null;
      _message = null;
    });
    try {
      await _licenseService.signOut();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _AccessGateStage.authorized) {
      return const MainShell();
    }

    final loading = _stage == _AccessGateStage.loading;
    final denied = _stage == _AccessGateStage.denied;
    final accent = denied ? appRed : appCyan;
    return Scaffold(
      backgroundColor: appBg,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.35),
                  radius: 1.25,
                  colors: <Color>[
                    Color(0xFF091527),
                    Color(0xFF07090D),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: appPanel.withAlpha(245),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: accent.withAlpha(170)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withAlpha(35),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.sports_soccer_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'DEPORTE TOTAL 360°',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'ACCESO PROTEGIDO · LICENCIA PERSONAL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (loading) ...<Widget>[
                          const CircularProgressIndicator(color: appCyan),
                          const SizedBox(height: 12),
                          const Text(
                            'Comprobando tu licencia...',
                            style: TextStyle(color: appMuted),
                          ),
                        ] else ...<Widget>[
                          Icon(
                            denied ? Icons.lock_outline_rounded :
                                Icons.verified_user_outlined,
                            color: accent,
                            size: 38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            denied ? 'LICENCIA NO ACTIVA' :
                                'IDENTIFÍCATE PARA CONTINUAR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          if (_email != null) ...<Widget>[
                            const SizedBox(height: 7),
                            Text(
                              _email!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: appMuted),
                            ),
                          ],
                          const SizedBox(height: 9),
                          Text(
                            _message ?? (denied
                                ? 'La compra o el pase gratuito se asocian a tu cuenta Google. Compartir el APK no comparte la licencia.'
                                : 'Accede con la cuenta Google vinculada a tu compra o invitación.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: appMuted,
                              height: 1.45,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _working ? null :
                                  (denied ? _changeAccount :
                                      (_stage == _AccessGateStage.error
                                          ? _restoreAndCheck
                                          : _signIn)),
                              icon: _working
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(denied ? Icons.switch_account_rounded :
                                      (_stage == _AccessGateStage.error
                                          ? Icons.refresh_rounded
                                          : Icons.login_rounded)),
                              label: Text(denied
                                  ? 'CAMBIAR CUENTA'
                                  : (_stage == _AccessGateStage.error
                                      ? 'VOLVER A INTENTAR'
                                      : 'ENTRAR CON GOOGLE')),
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (denied) ...<Widget>[
                            const SizedBox(height: 10),
                            const Text(
                              'Para comprar una licencia o recibir una invitación, contacta al administrador.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: appMuted,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
  late final ScrollController _bottomNavigationController;
  bool _bottomCanScrollLeft = false;
  bool _bottomCanScrollRight = false;

  @override
  void initState() {
    super.initState();
    _bottomNavigationController = ScrollController()
      ..addListener(_syncBottomNavigation);
    NotificationService.liveEventNotification.addListener(_handleLivePush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBottomNavigation());
    if (NotificationService.liveEventNotification.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleLivePush());
    }
  }

  void _handleLivePush() {
    final eventId = NotificationService.liveEventNotification.value;
    if (eventId == null || !mounted) return;
    _selectedAgendaEventId = eventId;
    NotificationService.liveEventNotification.value = null;
    _selectTab(_liveTab);
  }

  @override
  void dispose() {
    NotificationService.liveEventNotification.removeListener(_handleLivePush);
    _bottomNavigationController
      ..removeListener(_syncBottomNavigation)
      ..dispose();
    super.dispose();
  }

  void _syncBottomNavigation() {
    if (!mounted || !_bottomNavigationController.hasClients) return;
    final position = _bottomNavigationController.position;
    final canScrollLeft = position.pixels > 2;
    final canScrollRight = position.maxScrollExtent - position.pixels > 2;
    if (canScrollLeft == _bottomCanScrollLeft &&
        canScrollRight == _bottomCanScrollRight) {
      return;
    }
    setState(() {
      _bottomCanScrollLeft = canScrollLeft;
      _bottomCanScrollRight = canScrollRight;
    });
  }

  void _scrollBottomNavigation(bool forward) {
    if (!_bottomNavigationController.hasClients) return;
    final position = _bottomNavigationController.position;
    final direction = forward ? 1.0 : -1.0;
    final target = (position.pixels +
            direction * position.viewportDimension * .72)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    unawaited(
      _bottomNavigationController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  static const int _homeTab = 0;
  static const int _liveTab = 1;
  static const int _channelsTab = 2;
  static const int _agendaTab = 3;
  static const int _newsTab = 4;
  static const int _fantasyTab = 5;
  static const int _statisticsTab = 6;
  static const int _summariesTab = 7;
  static const int _chatTab = 8;
  static const int _settingsTab = 9;

  int _selectedIndex = _homeTab;
  String _selectedStatisticsSport = 'Todos';
  String? _selectedAgendaEventId;
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

  void _openAgenda() => _selectTab(_agendaTab);

  void _openPublicChat() => _selectTab(_chatTab);

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

  double _bottomNavigationItemWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 72;
    if (width < 480) return 76;
    if (width < 700) return 82;
    if (width < 1000) return 90;
    return 98;
  }

  Widget _buildBottomTab(int index, IconData icon, String label, Color accent) {
    final selected = _selectedIndex == index;
    final tabWidth = _bottomNavigationItemWidth(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => _selectTab(index),
        child: SizedBox(
          width: tabWidth,
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 19, color: selected ? accent : appMuted),
              const SizedBox(height: 3),
              Text(
                label,
                key: ValueKey<String>('bottom-tab-label-$index'),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? accent : appMuted,
                  fontSize: tabWidth < 78 ? 8 : 8.5,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomScrollCue({required bool forward}) {
    final label = forward
        ? 'Desplazar navegación a la derecha'
        : 'Desplazar navegación a la izquierda';
    return Positioned(
      left: forward ? null : 2,
      right: forward ? 2 : null,
      top: 7,
      bottom: 7,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey<String>(
                forward ? 'bottom-nav-scroll-right' : 'bottom-nav-scroll-left',
              ),
              borderRadius: BorderRadius.circular(20),
              onTap: () => _scrollBottomNavigation(forward),
              child: Container(
                width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xF507090D),
                  shape: BoxShape.circle,
                  border: Border.all(color: appCyan.withAlpha(185)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: appCyan.withAlpha(55),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  forward
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: appCyan,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reserva dos carriles estables cuando las diez pestañas no caben.
    // Así la aparición/desaparición de las flechas no cambia el viewport ni
    // desplaza el contenido mientras el usuario recorre la navegación.
    final navigationNeedsScroll =
        _bottomNavigationItemWidth(context) * 10 > MediaQuery.sizeOf(context).width;

    final pages = <Widget>[
      HomeDashboard(
        onNavigate: _selectTab,
        onSportSelected: _selectSport,
        onTelegram: _openTelegram,
        onContact: () => openExternalLink(context, contactUrl, label: 'WhatsApp'),
        onDonations: _openDonations,
        onFantasy: _openFantasy,
        onStatistics: _openStatistics,
        onOpenAgenda: _openAgenda,
        onChat: _openPublicChat,
      ),
      _visitedTabs.contains(_liveTab)
          ? AutomaticLiveScreen(
              onOpenAgenda: () => _selectTab(_agendaTab),
              isActive: _selectedIndex == _liveTab,
              selectedEventId: _selectedAgendaEventId,
            )
          : const SizedBox.shrink(),
      _visitedTabs.contains(_channelsTab)
          ? const ChannelCatalogScreen()
          : const SizedBox.shrink(),
      _visitedTabs.contains(_agendaTab)
          ? SportsAgendaScreen(
              isActive: _selectedIndex == _agendaTab,
              onOpenLive: (eventId) {
                _selectedAgendaEventId = eventId;
                _selectTab(_liveTab);
              },
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
      _visitedTabs.contains(_chatTab)
          ? PublicChatScreen(isActive: _selectedIndex == _chatTab)
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
        body: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            pages.length,
            (index) => TickerMode(
              enabled: index == _selectedIndex,
              child: RepaintBoundary(child: pages[index]),
            ),
            growable: false,
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            border: const Border(top: BorderSide(color: appLine)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: appCyan.withAlpha(18), blurRadius: 18, offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 66,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  Padding(
                    // Reserva el espacio de las flechas: nunca deben tapar el
                    // texto ni el icono de una sección de navegación.
                    padding: EdgeInsets.symmetric(
                      horizontal: navigationNeedsScroll ? 38 : 0,
                    ),
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: (_) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _syncBottomNavigation(),
                        );
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _bottomNavigationController,
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            _buildBottomTab(_homeTab, Icons.home_rounded, tr('home'), appCyan),
                            _buildBottomTab(_liveTab, Icons.live_tv_rounded, 'Deportes en vivo', appPink),
                            _buildBottomTab(_channelsTab, Icons.grid_view_rounded, 'Canales deportivos', appCyan),
                            _buildBottomTab(_agendaTab, Icons.calendar_month_rounded, 'Agenda de hoy', appGreen),
                            _buildBottomTab(_newsTab, Icons.article_rounded, tr('news'), appGreen),
                            _buildBottomTab(_fantasyTab, Icons.emoji_events_rounded, 'Mister Fantasy', appYellow),
                            _buildBottomTab(_statisticsTab, Icons.query_stats_rounded, tr('statistics'), appCyan),
                            _buildBottomTab(
                              _summariesTab,
                              Icons.play_circle_fill_rounded,
                              appText('Resúmenes', 'Highlights', 'Resumos', 'Résumés'),
                              appRed,
                            ),
                            _buildBottomTab(_chatTab, Icons.forum_rounded, tr('chat'), appGreen),
                            _buildBottomTab(_settingsTab, Icons.settings_rounded, tr('settings'), appBlue),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_bottomCanScrollLeft)
                    _buildBottomScrollCue(forward: false),
                  if (_bottomCanScrollRight)
                    _buildBottomScrollCue(forward: true),
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
  Widget build(BuildContext context) => ColoredBox(color: appBg, child: child);
}

/// Fondo original de Ajustes: conserva la fotografía del proyecto y la oscurece
/// para que los controles sigan siendo legibles.
class SettingsBackdrop extends StatelessWidget {
  const SettingsBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(color: appBg, child: child);
}

// Tonos del escudo y del fondo de Inicio, usando solo la identidad de cinco colores.
const Color _homeBlack = Color(0xFF020204);
const Color _homePanel = Color(0xFF07090D);
const Color _homeSteel = Color(0xFFEAF0F8);
const Color _homeWhite = Color(0xFFFFFFFF);
const Color _homeBlue = Color(0xFF00A3FF);
const Color _homeRed = Color(0xFFFF1744);
const Color _homeGreen = Color(0xFF39FF14);

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

  // Se mantienen todos los callbacks y contratos existentes.
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
      backgroundColor: _homeBlack,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.35),
                radius: 1.2,
                colors: <Color>[
                  Color(0xFF05080D),
                  _homePanel,
                  _homeBlack,
                ],
              ),
            ),
          ),
          CustomPaint(painter: _HomeAtmospherePainter()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactLandscape =
                    constraints.maxWidth > constraints.maxHeight * 1.3 &&
                    constraints.maxHeight < 560;
                final compact = constraints.maxHeight < 540 ||
                    constraints.maxWidth < 360 ||
                    compactLandscape;
                final widthLimit = constraints.maxWidth * .92;
                final preferredWidth = compactLandscape
                    ? (constraints.maxHeight * .40)
                        .clamp(148.0, 260.0)
                        .toDouble()
                    : (constraints.maxHeight * .55)
                        .clamp(210.0, 410.0)
                        .toDouble();
                final crestWidth = math.min(
                  math.min(preferredWidth, widthLimit),
                  compactLandscape ? 260.0 : 410.0,
                ).toDouble();

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: compact ? 7 : 15,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const _HomeWordmark(),
                          SizedBox(height: compact ? 5 : 12),
                          Semantics(
                            image: true,
                            label: appText(
                              'Escudo deportivo de Deporte Total 360 grados, con iluminación azul, roja y verde.',
                              'Deporte Total 360 sports crest with blue, red and green lighting.',
                              'Escudo esportivo Deporte Total 360 graus com iluminação azul, vermelha e verde.',
                              'Écusson sportif Deporte Total 360 degrés avec éclairage bleu, rouge et vert.',
                            ),
                            child: SizedBox(
                              key: const ValueKey<String>('home-sports-crest'),
                              width: crestWidth,
                              height: crestWidth * 1.12,
                              child: const RepaintBoundary(child: _SportsCrest()),
                            ),
                          ),
                          SizedBox(height: compact ? 5 : 12),
                          Text(
                            appText(
                              'TODO EL DEPORTE',
                              'ALL SPORTS',
                              'TODO O ESPORTE',
                              'TOUT LE SPORT',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _homeWhite,
                              fontSize: compact ? 19 : 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              height: 1.02,
                              shadows: <Shadow>[
                                Shadow(color: _homeBlue.withAlpha(180), blurRadius: 20),
                                const Shadow(color: Colors.black, blurRadius: 5, offset: Offset(0, 3)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            appText(
                              'EN UN SOLO LUGAR',
                              'IN ONE PLACE',
                              'EM UM SÓ LUGAR',
                              'AU MÊME ENDROIT',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _homeBlue,
                              fontSize: compact ? 17 : 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                              height: 1.12,
                              shadows: <Shadow>[
                                Shadow(color: _homeBlue.withAlpha(170), blurRadius: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('tagline'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _homeSteel.withAlpha(220),
                              fontSize: compact ? 9 : 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _HomeEnergyRail(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _homeWordmarkLine(_homeBlue),
            const SizedBox(width: 10),
            Text(
              tr('title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _homeWhite,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                shadows: <Shadow>[
                  Shadow(color: _homeBlue, blurRadius: 12),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _homeWordmarkLine(_homeRed),
          ],
        ),
      ),
    );
  }

  Widget _homeWordmarkLine(Color color) => Container(
        width: 24,
        height: 2.5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          boxShadow: <BoxShadow>[
            BoxShadow(color: color.withAlpha(190), blurRadius: 10),
          ],
        ),
      );
}

class _HomeEnergyRail extends StatelessWidget {
  const _HomeEnergyRail();

  @override
  Widget build(BuildContext context) {
    final items = <(Color, String)>[
      (_homeBlue, '360°'),
      (_homeRed, 'SPORT'),
      (_homeGreen, 'LIVE'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 7,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: item.$1.withAlpha(18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: item.$1.withAlpha(180), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(color: item.$1.withAlpha(30), blurRadius: 6),
            ],
          ),
          child: Text(
            item.$2,
            style: TextStyle(
              color: item.$1,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SportsCrest extends StatefulWidget {
  const _SportsCrest();

  @override
  State<_SportsCrest> createState() => _SportsCrestState();
}

class _SportsCrestState extends State<_SportsCrest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta la preferencia de accesibilidad del sistema para reducir
    // movimiento y evita animaciones permanentes cuando el usuario las desactiva.
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final progress = _motion.value;
        final pulse = 1 + math.sin(progress * math.pi * 2) * .004;
        return Transform.scale(
          scale: pulse,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
      
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(painter: _SportsCrestPainter(progress)),
                  ),
                  // Aro mecánico exterior con bisel metálico y sombra profunda.
                  Align(
                    alignment: const Alignment(0, -.04),
                    child: Container(
                      width: width * .59,
                      height: width * .59,
                      padding: EdgeInsets.all(width * .035),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFFF1F6FC),
                            Color(0xFF52677F),
                            Color(0xFF111C2A),
                            Color(0xFF8295AA),
                            Color(0xFF030303),
                          ],
                          stops: <double>[0, .22, .52, .76, 1],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: _homeBlue.withAlpha(85), blurRadius: width * .045),
                          BoxShadow(color: Colors.black.withAlpha(220), blurRadius: width * .055, offset: Offset(width * .035, width * .045)),
                        ],
                      ),
                      child: Container(
                        padding: EdgeInsets.all(width * .035),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _homeBlack,
                          border: Border.all(color: _homeBlue.withAlpha(220), width: 2),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(width * .025),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-.3, -.4),
                              colors: <Color>[
                                Color(0xFF333333),
                                Color(0xFF080808),
                                Color(0xFF02050B),
                              ],
                            ),
                            border: Border.all(color: _homeSteel.withAlpha(130), width: 1),
                          ),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.contain,
                            cacheWidth: 640,
                            cacheHeight: 640,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.emoji_events_rounded,
                              color: _homeWhite,
                              size: width * .22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * .39,
                    top: height * .025,
                    child: _CrestSportOrb(icon: Icons.smart_toy_rounded, color: _homeWhite, size: width * .22),
                  ),
                  Positioned(
                    left: width * .025,
                    top: height * .29,
                    child: _CrestSportOrb(icon: Icons.sports_soccer_rounded, color: _homeBlue, size: width * .2),
                  ),
                  Positioned(
                    right: width * .025,
                    top: height * .29,
                    child: _CrestSportOrb(icon: Icons.sports_basketball_rounded, color: _homeRed, size: width * .2),
                  ),
                  Positioned(
                    left: width * .12,
                    bottom: height * .18,
                    child: _CrestSportOrb(icon: Icons.sports_baseball_rounded, color: _homeWhite, size: width * .16),
                  ),
                  Positioned(
                    right: width * .12,
                    bottom: height * .18,
                    child: _CrestSportOrb(icon: Icons.sports_volleyball_rounded, color: _homeGreen, size: width * .16),
                  ),
                  Positioned(
                    left: width * .2,
                    right: width * .2,
                    bottom: height * .045,
                    child: Container(
                      height: width * .14,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width * .045),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0xFFC6CFDA),
                            Color(0xFF090909),
                            Color(0xFF030303),
                          ],
                        ),
                        border: Border.all(color: _homeBlue, width: 1.5),
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: _homeBlue.withAlpha(105), blurRadius: width * .05),
                          BoxShadow(color: Colors.black.withAlpha(210), blurRadius: 9, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Text(
                        '360°',
                        style: TextStyle(
                          color: _homeWhite,
                          fontSize: width * .078,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: <Shadow>[
                            Shadow(color: _homeBlue.withAlpha(220), blurRadius: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _CrestSportOrb extends StatelessWidget {
  const _CrestSportOrb({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: <Color>[
            Color(0xFF454545),
            Color(0xFF111111),
            Color(0xFF020204),
          ],
        ),
        border: Border.all(color: color, width: 1.7),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withAlpha(100), blurRadius: size * .24),
          BoxShadow(color: Colors.black.withAlpha(210), blurRadius: size * .12, offset: Offset(size * .06, size * .08)),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * .09),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _homeSteel.withAlpha(75), width: .8),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * .49,
          shadows: <Shadow>[
            Shadow(color: color.withAlpha(205), blurRadius: size * .25),
          ],
        ),
      ),
    );
  }
}

class _SportsCrestPainter extends CustomPainter {
  const _SportsCrestPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final shield = Path()
      ..moveTo(width * .5, height * .018)
      ..cubicTo(width * .72, height * .008, width * .92, height * .07, width * .97, height * .2)
      ..lineTo(width * .9, height * .72)
      ..cubicTo(width * .86, height * .87, width * .64, height * .97, width * .5, height * .99)
      ..cubicTo(width * .36, height * .97, width * .14, height * .87, width * .1, height * .72)
      ..lineTo(width * .03, height * .2)
      ..cubicTo(width * .08, height * .07, width * .28, height * .008, width * .5, height * .018)
      ..close();

    final bounds = Offset.zero & size;
    // Halo azul y rojo detrás de la silueta.
    canvas.drawPath(
      shield,
      Paint()
        ..color = _homeBlue.withAlpha(115)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .075,
    );
    canvas.save();
    canvas.translate(width * .012, height * .014);
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.black.withAlpha(235)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .055,
    );
    canvas.restore();

    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE6EDF5),
            Color(0xFFB8C1CC),
            Color(0xFF101010),
            Color(0xFF030303),
            Color(0xFF202020),
          ],
          stops: <double>[0, .18, .43, .76, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = _homeWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .012,
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = _homeBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .006,
    );

    // Paneles angulares que dan aspecto de armadura robótica.
    final armor = Paint()
      ..color = _homeSteel.withAlpha(105)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * .006
      ..strokeJoin = StrokeJoin.round;
    final leftPlate = Path()
      ..moveTo(width * .13, height * .22)
      ..lineTo(width * .29, height * .16)
      ..lineTo(width * .24, height * .39)
      ..lineTo(width * .15, height * .48)
      ..close();
    final rightPlate = Path()
      ..moveTo(width * .87, height * .22)
      ..lineTo(width * .71, height * .16)
      ..lineTo(width * .76, height * .39)
      ..lineTo(width * .85, height * .48)
      ..close();
    canvas.drawPath(leftPlate, armor);
    canvas.drawPath(rightPlate, armor);

    final centerRing = Rect.fromCenter(
      center: Offset(width * .5, height * .48),
      width: width * .76,
      height: height * .47,
    );
    canvas.drawOval(
      centerRing,
      Paint()
        ..color = _homeBlue.withAlpha(95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .009,
    );
    canvas.drawOval(
      centerRing.deflate(width * .025),
      Paint()
        ..color = _homeRed.withAlpha(95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .004,
    );

    // Circuitos laterales y remaches luminosos.
    final circuit = Paint()
      ..color = _homeGreen.withAlpha(175)
      ..strokeWidth = width * .004
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final side in <double>[-1, 1]) {
      final x = side < 0 ? width * .2 : width * .8;
      canvas.drawLine(Offset(x, height * .53), Offset(x + side * width * .055, height * .61), circuit);
      canvas.drawLine(Offset(x + side * width * .055, height * .61), Offset(x + side * width * .035, height * .69), circuit);
      canvas.drawCircle(Offset(x, height * .53), width * .009, Paint()..color = _homeGreen);
    }

    final topLine = Paint()
      ..color = _homeRed
      ..strokeWidth = width * .006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(width * .34, height * .105), Offset(width * .66, height * .105), topLine);
    canvas.drawCircle(Offset(width * .5, height * .105), width * .014, Paint()..color = _homeWhite);
    canvas.drawCircle(Offset(width * .5, height * .105), width * .027, Paint()..color = _homeBlue.withAlpha(65));

    // Segmento luminoso que recorre el bisel para reforzar el efecto mecánico.
    final metrics = shield.computeMetrics().toList(growable: false);
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final length = metric.length;
      final start = (progress * length) % length;
      final end = start + length * .13;
      final sweep = Path();
      if (end <= length) {
        sweep.addPath(metric.extractPath(start, end), Offset.zero);
      } else {
        sweep
          ..addPath(metric.extractPath(start, length), Offset.zero)
          ..addPath(metric.extractPath(0, end - length), Offset.zero);
      }
      canvas.drawPath(
        sweep,
        Paint()
          ..color = _homeBlue.withAlpha(175)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * .018
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * .008),
      );
      canvas.drawPath(
        sweep,
        Paint()
          ..color = _homeWhite.withAlpha(205)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * .0035
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SportsCrestPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HomeAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .46);
    for (var i = 0; i < 6; i++) {
      final opacity = 25 - (i * 3);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * (.76 + (i * .34)),
          height: size.height * (.25 + (i * .13)),
        ),
        Paint()
          ..color = (i % 3 == 0 ? _homeRed : (i.isEven ? _homeBlue : _homeGreen)).withAlpha(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.5 : 1,
      );
    }

    final blueBeam = Paint()..color = _homeBlue.withAlpha(24)..strokeWidth = 1.2;
    final redBeam = Paint()..color = _homeRed.withAlpha(20)..strokeWidth = 1;
    final greenBeam = Paint()..color = _homeGreen.withAlpha(18)..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * .23), Offset(size.width * .28, size.height * .43), blueBeam);
    canvas.drawLine(Offset(size.width, size.height * .23), Offset(size.width * .72, size.height * .43), redBeam);
    canvas.drawLine(Offset(0, size.height * .77), Offset(size.width * .28, size.height * .59), greenBeam);
    canvas.drawLine(Offset(size.width, size.height * .77), Offset(size.width * .72, size.height * .59), blueBeam);

    // Puntos tipo interfaz HUD alrededor del escudo.
    final dotPaint = Paint()..color = _homeWhite.withAlpha(85);
    for (var i = 0; i < 18; i++) {
      final x = size.width * ((i * 37 % 97) / 100);
      final y = size.height * ((i * 53 % 91) / 100);
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.7 : 1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeAtmospherePainter oldDelegate) => false;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.adminService});

  final ChannelCatalogService? adminService;

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
      if (mounted) {
        final enabled = prefs.getBool('notifications_enabled') ?? false;
        NotificationService.matchRemindersEnabled.value = enabled;
        setState(() => _notificationsEnabled = enabled);
      }
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
    NotificationService.matchRemindersEnabled.value = enabled;
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
          builder: (_) => ChannelAdminScreen(service: widget.adminService),
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
        title: AppSectionTitle(
          icon: Icons.settings_rounded,
          title: tr('settings').toUpperCase(),
          accent: appCyan,
          subtitle: 'PERSONALIZA DEPORTE TOTAL 360°',
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
                color: appPanel,
                border: Border.all(color: appCyan.withAlpha(170)),
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
                      'Servidor de estadísticas',
                      'Statistics server',
                      'Servidor de estatísticas',
                      'Serveur des statistiques',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    appText(
                      'Comprobar la conexión del servicio de estadísticas y configurar el Worker.',
                      'Check the statistics service and configure the public Worker URL.',
                      'Verifique a conexão do serviço de estatísticas e configure o Worker.',
                      'Vérifier le service de statistiques et configurer le Worker.',
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
        title: AppSectionTitle(
          icon: Icons.storage_rounded,
          title: appText('SERVIDOR Y DATOS DEPORTIVOS', 'SPORTS DATA SERVER', 'SERVIDOR E DADOS ESPORTIVOS', 'SERVEUR ET DONNÉES SPORTIVES'),
          accent: appCyan,
          subtitle: 'CONEXIÓN Y CONFIGURACIÓN',
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
                children: const <Widget>[
                  Row(children: <Widget>[
                    Icon(Icons.auto_awesome_rounded, color: appPink),
                    SizedBox(width: 9),
                    Expanded(child: Text(
                      'FUENTES DEPORTIVAS AUTOMÁTICAS',
                      style: TextStyle(color: appPink, fontWeight: FontWeight.w900, fontSize: 12),
                    )),
                  ]),
                  SizedBox(height: 9),
                  Text(
                    'Las listas de canales y guías de programación se descargan y actualizan automáticamente. Primero se priorizan señales en español; cuando no hay una señal española disponible, se prueban fuentes internacionales. Las direcciones y el catálogo permanecen ocultos en la interfaz y no requieren validación manual del usuario.',
                    style: TextStyle(color: appMuted, fontSize: 11, height: 1.45),
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
