import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'web_agenda_screen.dart';

const Color bg = Color(0xFF020817);
const Color panel = Color(0xFF071B35);
const Color cyan = Color(0xFF00E5FF);
const Color pink = Color(0xFFFF28CF);
const Color green = Color(0xFF39FF9C);
const Color yellow = Color(0xFFFFD600);
const Color muted = Color(0xFFB4C4D9);
const Color liveRed = Color(0xFFFF1744);

const String agendaUrl = 'https://futbol-libre.cam/';
const String fallbackAgendaUrl = 'https://www.espn.com/soccer/scoreboard';
const String telegramUrl = 'https://t.me/';
const String contactUrl = 'https://wa.me/';
const String rtmpBase = 'rtmp://ssh101.bozztv.com/ssh101/';
const String hlsBase = 'https://live21.bozztv.com/akamaissh101/ssh101/';
const String settingsPhotoAsset =
    'assets/images/file_000000006048820e9e0720f1adf548f1.png';

enum AppLanguage { spanish, english, portuguese, french }

final ValueNotifier<AppLanguage> appLanguage =
    ValueNotifier<AppLanguage>(AppLanguage.spanish);
final ValueNotifier<String> channelSlug = ValueNotifier<String>('');

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

const Map<String, Map<AppLanguage, String>> _text = {
  'app_title': {
    AppLanguage.spanish: 'DEPORTE TOTAL 360°',
    AppLanguage.english: 'TOTAL SPORTS 360°',
    AppLanguage.portuguese: 'ESPORTE TOTAL 360°',
    AppLanguage.french: 'SPORT TOTAL 360°',
  },
  'tagline': {
    AppLanguage.spanish: 'TODOS LOS DEPORTES EN UN SOLO LUGAR',
    AppLanguage.english: 'ALL SPORTS IN ONE PLACE',
    AppLanguage.portuguese: 'TODOS OS ESPORTES EM UM SÓ LUGAR',
    AppLanguage.french: 'TOUS LES SPORTS AU MÊME ENDROIT',
  },
  'live': {
    AppLanguage.spanish: 'TRANSMISIONES',
    AppLanguage.english: 'LIVE STREAMS',
    AppLanguage.portuguese: 'TRANSMISSÕES',
    AppLanguage.french: 'DIRECT',
  },
  'agenda': {
    AppLanguage.spanish: 'AGENDA',
    AppLanguage.english: 'SCHEDULE',
    AppLanguage.portuguese: 'AGENDA',
    AppLanguage.french: 'PROGRAMME',
  },
  'matches': {
    AppLanguage.spanish: 'AGENDA DE PARTIDOS',
    AppLanguage.english: 'MATCH SCHEDULE',
    AppLanguage.portuguese: 'AGENDA DE JOGOS',
    AppLanguage.french: 'CALENDRIER DES MATCHS',
  },
  'telegram': {
    AppLanguage.spanish: 'TELEGRAM',
    AppLanguage.english: 'TELEGRAM',
    AppLanguage.portuguese: 'TELEGRAM',
    AppLanguage.french: 'TELEGRAM',
  },
  'official_channel': {
    AppLanguage.spanish: 'CANAL OFICIAL',
    AppLanguage.english: 'OFFICIAL CHANNEL',
    AppLanguage.portuguese: 'CANAL OFICIAL',
    AppLanguage.french: 'CHAÎNE OFFICIELLE',
  },
  'settings': {
    AppLanguage.spanish: 'AJUSTES',
    AppLanguage.english: 'SETTINGS',
    AppLanguage.portuguese: 'CONFIGURAÇÕES',
    AppLanguage.french: 'PARAMÈTRES',
  },
  'language': {
    AppLanguage.spanish: 'Idioma',
    AppLanguage.english: 'Language',
    AppLanguage.portuguese: 'Idioma',
    AppLanguage.french: 'Langue',
  },
  'stream_setup': {
    AppLanguage.spanish: 'CONFIGURACIÓN DE TRANSMISIÓN',
    AppLanguage.english: 'STREAM SETTINGS',
    AppLanguage.portuguese: 'CONFIGURAÇÃO DA TRANSMISSÃO',
    AppLanguage.french: 'CONFIGURATION DU DIRECT',
  },
  'channel_slug': {
    AppLanguage.spanish: 'Identificador del canal SSH101',
    AppLanguage.english: 'SSH101 channel slug',
    AppLanguage.portuguese: 'Identificador do canal SSH101',
    AppLanguage.french: 'Identifiant de chaîne SSH101',
  },
  'channel_hint': {
    AppLanguage.spanish: 'Escribe el nombre de canal creado en BozzTV',
    AppLanguage.english: 'Enter the channel name created on BozzTV',
    AppLanguage.portuguese: 'Digite o nome de canal criado na BozzTV',
    AppLanguage.french: 'Saisissez le nom de chaîne créé sur BozzTV',
  },
  'save': {
    AppLanguage.spanish: 'GUARDAR CONFIGURACIÓN',
    AppLanguage.english: 'SAVE SETTINGS',
    AppLanguage.portuguese: 'SALVAR CONFIGURAÇÃO',
    AppLanguage.french: 'ENREGISTRER',
  },
  'rtmp': {
    AppLanguage.spanish: 'Servidor RTMP para PRISM (emisión)',
    AppLanguage.english: 'RTMP server for PRISM (broadcast)',
    AppLanguage.portuguese: 'Servidor RTMP para PRISM (transmissão)',
    AppLanguage.french: 'Serveur RTMP pour PRISM (émission)',
  },
  'hls': {
    AppLanguage.spanish: 'URL HLS para ver en la APK',
    AppLanguage.english: 'HLS URL for playback in the app',
    AppLanguage.portuguese: 'URL HLS para assistir no app',
    AppLanguage.french: 'URL HLS pour lire dans l’application',
  },
  'copy': {
    AppLanguage.spanish: 'COPIAR',
    AppLanguage.english: 'COPY',
    AppLanguage.portuguese: 'COPIAR',
    AppLanguage.french: 'COPIER',
  },
  'saved': {
    AppLanguage.spanish: 'Configuración guardada.',
    AppLanguage.english: 'Settings saved.',
    AppLanguage.portuguese: 'Configuração salva.',
    AppLanguage.french: 'Configuration enregistrée.',
  },
  'invalid_channel': {
    AppLanguage.spanish: 'Usa solo letras, números, guion y guion bajo.',
    AppLanguage.english: 'Use only letters, numbers, hyphens and underscores.',
    AppLanguage.portuguese: 'Use apenas letras, números, hífen e sublinhado.',
    AppLanguage.french: 'Utilisez uniquement lettres, chiffres, tirets et soulignements.',
  },
  'configure_first': {
    AppLanguage.spanish: 'Primero escribe y guarda el identificador del canal en Ajustes.',
    AppLanguage.english: 'Enter and save the channel slug in Settings first.',
    AppLanguage.portuguese: 'Primeiro informe e salve o identificador em Configurações.',
    AppLanguage.french: 'Saisissez et enregistrez d’abord l’identifiant dans Paramètres.',
  },
  'player': {
    AppLanguage.spanish: 'REPRODUCCIÓN EN VIVO',
    AppLanguage.english: 'LIVE PLAYER',
    AppLanguage.portuguese: 'REPRODUÇÃO AO VIVO',
    AppLanguage.french: 'LECTEUR EN DIRECT',
  },
  'play': {
    AppLanguage.spanish: 'REPRODUCIR',
    AppLanguage.english: 'PLAY',
    AppLanguage.portuguese: 'REPRODUZIR',
    AppLanguage.french: 'LECTURE',
  },
  'pause': {
    AppLanguage.spanish: 'PAUSAR',
    AppLanguage.english: 'PAUSE',
    AppLanguage.portuguese: 'PAUSAR',
    AppLanguage.french: 'PAUSE',
  },
  'retry': {
    AppLanguage.spanish: 'REINTENTAR',
    AppLanguage.english: 'RETRY',
    AppLanguage.portuguese: 'TENTAR NOVAMENTE',
    AppLanguage.french: 'RÉESSAYER',
  },
  'channel_missing': {
    AppLanguage.spanish: 'Aún no has configurado el canal SSH101.',
    AppLanguage.english: 'The SSH101 channel is not configured yet.',
    AppLanguage.portuguese: 'O canal SSH101 ainda não foi configurado.',
    AppLanguage.french: 'La chaîne SSH101 n’est pas encore configurée.',
  },
  'stream_error': {
    AppLanguage.spanish:
        'No se pudo iniciar el vídeo. Comprueba que el canal esté emitiendo y que la URL HLS sea válida.',
    AppLanguage.english:
        'Video could not start. Check that the channel is live and the HLS URL is valid.',
    AppLanguage.portuguese:
        'Não foi possível iniciar o vídeo. Verifique se o canal está ao vivo e se a URL HLS é válida.',
    AppLanguage.french:
        'Impossible de lancer la vidéo. Vérifiez que la chaîne est en direct et que l’URL HLS est valide.',
  },
  'encoder': {
    AppLanguage.spanish: 'CONFIGURAR PRISM',
    AppLanguage.english: 'CONFIGURE PRISM',
    AppLanguage.portuguese: 'CONFIGURAR PRISM',
    AppLanguage.french: 'CONFIGURER PRISM',
  },
  'viewer': {
    AppLanguage.spanish: 'SSH101 · VER TRANSMISIÓN',
    AppLanguage.english: 'SSH101 · WATCH STREAM',
    AppLanguage.portuguese: 'SSH101 · ASSISTIR À TRANSMISSÃO',
    AppLanguage.french: 'SSH101 · REGARDER LE DIRECT',
  },
  'live_here': {
    AppLanguage.spanish: 'EN VIVO AQUÍ',
    AppLanguage.english: 'LIVE HERE',
    AppLanguage.portuguese: 'AO VIVO AQUI',
    AppLanguage.french: 'EN DIRECT ICI',
  },
  'copy_done': {
    AppLanguage.spanish: 'Copiado al portapapeles.',
    AppLanguage.english: 'Copied to clipboard.',
    AppLanguage.portuguese: 'Copiado para a área de transferência.',
    AppLanguage.french: 'Copié dans le presse-papiers.',
  },
  'settings_help': {
    AppLanguage.spanish:
        'Introduce solo el identificador del canal, no la URL completa ni los símbolos < >.',
    AppLanguage.english:
        'Enter only the channel slug, not the full URL or the < > symbols.',
    AppLanguage.portuguese:
        'Digite apenas o identificador do canal, não a URL completa nem os símbolos < >.',
    AppLanguage.french:
        'Saisissez uniquement l’identifiant, sans l’URL complète ni les symboles < >.',
  },
  'football': {
    AppLanguage.spanish: 'FÚTBOL',
    AppLanguage.english: 'SOCCER',
    AppLanguage.portuguese: 'FUTEBOL',
    AppLanguage.french: 'FOOTBALL',
  },
  'basketball': {
    AppLanguage.spanish: 'BALONCESTO',
    AppLanguage.english: 'BASKETBALL',
    AppLanguage.portuguese: 'BASQUETE',
    AppLanguage.french: 'BASKET',
  },
  'tennis': {
    AppLanguage.spanish: 'TENIS',
    AppLanguage.english: 'TENNIS',
    AppLanguage.portuguese: 'TÊNIS',
    AppLanguage.french: 'TENNIS',
  },
  'combat': {
    AppLanguage.spanish: 'COMBATE',
    AppLanguage.english: 'COMBAT',
    AppLanguage.portuguese: 'LUTAS',
    AppLanguage.french: 'COMBAT',
  },
  'volleyball': {
    AppLanguage.spanish: 'VÓLEIBOL',
    AppLanguage.english: 'VOLLEYBALL',
    AppLanguage.portuguese: 'VÔLEI',
    AppLanguage.french: 'VOLLEY',
  },
  'contact': {
    AppLanguage.spanish: 'CONTACTO',
    AppLanguage.english: 'CONTACT',
    AppLanguage.portuguese: 'CONTATO',
    AppLanguage.french: 'CONTACT',
  },
  'support': {
    AppLanguage.spanish: 'APOYO AL PROYECTO',
    AppLanguage.english: 'SUPPORT THE PROJECT',
    AppLanguage.portuguese: 'APOIE O PROJETO',
    AppLanguage.french: 'SOUTENIR LE PROJET',
  },
};

String tr(String key) => _text[key]?[appLanguage.value] ?? key;

String buildRtmpUrl(String channel) => '$rtmpBase$channel';
String buildHlsUrl(String channel) => '$hlsBase$channel/playlist.m3u8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final prefs = await SharedPreferences.getInstance();
    appLanguage.value = parseLanguage(prefs.getString('app_language'));
    channelSlug.value = prefs.getString('ssh101_channel') ?? '';
  } catch (_) {
    appLanguage.value = AppLanguage.spanish;
    channelSlug.value = '';
  }

  runApp(const DeporteTotal360App());
}

class DeporteTotal360App extends StatelessWidget {
  const DeporteTotal360App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        return MaterialApp(
          title: tr('app_title'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              ),
            ),
          ),
          home: const HomeScreen(),
        );
      },
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
        Opacity(
          opacity: .13,
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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

/// Fondo especial de Ajustes: fotografía del propietario,
/// un filtro oscuro y el rótulo neón Damian.apk.
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
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66020817),
                Color(0x99020817),
                Color(0xDC020817),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

Future<void> openWeb(
  BuildContext context, {
  String url = agendaUrl,
  String title = 'AGENDA DE PARTIDOS',
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WebAgendaScreen(initialUrl: url, pageTitle: title),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          tr('app_title'),
          style: const TextStyle(
            color: cyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: tr('settings'),
            onPressed: () => _open(context, const SettingsScreen()),
            icon: const Icon(Icons.settings_rounded, color: cyan),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 165,
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
                    border: Border.all(color: cyan.withValues(alpha: .65)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: cyan.withValues(alpha: .2),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.emoji_events_rounded,
                      color: yellow,
                      size: 86,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
                        title: tr('live'),
                        subtitle: 'PRISM • SSH101',
                        color: const Color(0xFFFF3159),
                        onTap: () => _open(context, const LiveScreen()),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.calendar_month_rounded,
                        title: tr('agenda'),
                        subtitle: tr('matches'),
                        color: green,
                        onTap: () => openWeb(context),
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
                        title: tr('telegram'),
                        subtitle: tr('official_channel'),
                        color: cyan,
                        onTap: () => _launchExternal(context, telegramUrl),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.settings_rounded,
                        title: tr('settings'),
                        subtitle: tr('language'),
                        color: yellow,
                        onTap: () => _open(context, const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => openWeb(context),
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(tr('matches')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _launchExternal(context, contactUrl),
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(tr('contact')),
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

Future<void> _launchExternal(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }
}

class _SportsStrip extends StatelessWidget {
  const _SportsStrip();

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String)>[
      (Icons.sports_soccer_rounded, tr('football')),
      (Icons.sports_basketball_rounded, tr('basketball')),
      (Icons.sports_tennis_rounded, tr('tennis')),
      (Icons.sports_mma_rounded, tr('combat')),
      (Icons.sports_volleyball_rounded, tr('volleyball')),
    ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final item = entries[index];

          return Container(
            width: 92,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: panel.withValues(alpha: .84),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: cyan.withValues(alpha: .35)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(item.$1, color: cyan, size: 25),
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
          constraints: const BoxConstraints(minHeight: 106),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .85)),
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

  Future<void> _openPlayer(BuildContext context) async {
    final slug = channelSlug.value.trim();

    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('configure_first'))),
      );
      await Navigator.of(context).push<void>(
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
      appBar: AppBar(title: Text(tr('live'))),
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
                  border: Border.all(color: cyan.withValues(alpha: .8)),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.live_tv_rounded,
                      color: pink,
                      size: 55,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('stream_setup'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: cyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('settings_help'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                subtitle: tr('encoder'),
                color: pink,
                icon: Icons.settings_input_antenna_rounded,
                onTap: () => _openEncoder(context),
              ),
              const SizedBox(height: 12),
              _ChannelTile(
                name: 'SSH101',
                subtitle: tr('live_here'),
                color: cyan,
                icon: Icons.play_circle_fill_rounded,
                onTap: () => _openPlayer(context),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => openWeb(context),
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(tr('matches')),
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
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final Color color;
  final IconData icon;
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
                color: color.withValues(alpha: .16),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
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

class EncoderConfigScreen extends StatelessWidget {
  const EncoderConfigScreen({super.key});

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('copy_done'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = channelSlug.value.trim();
    final rtmp = slug.isEmpty ? '$rtmpBase<TU_CANAL>' : buildRtmpUrl(slug);
    final hls = slug.isEmpty
        ? '${hlsBase}<TU_CANAL>/playlist.m3u8'
        : buildHlsUrl(slug);

    return Scaffold(
      appBar: AppBar(title: Text(tr('encoder'))),
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _InfoCard(
                title: tr('rtmp'),
                value: rtmp,
                onCopy: () => _copy(context, rtmp),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: tr('hls'),
                value: hls,
                onCopy: () => _copy(context, hls),
              ),
              const SizedBox(height: 16),
              Text(
                tr('settings_help'),
                style: const TextStyle(color: muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                child: Text(tr('settings')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.onCopy,
  });

  final String title;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cyan.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: cyan,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: Text(tr('copy')),
            ),
          ),
        ],
      ),
    );
  }
}

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({super.key, required this.channel});

  final String channel;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;

  String get _hlsUrl => buildHlsUrl(widget.channel);

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }

    final old = _controller;
    _controller = null;

    if (old != null) {
      await old.dispose();
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_hlsUrl),
    );
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted) return;

      setState(() => _initializing = false);
      await controller.play();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = tr('stream_error');
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
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(tr('player'))),
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyan),
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: controller != null &&
                          controller.value.isInitialized
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: _initializing
                      ? const Center(
                          child: CircularProgressIndicator(color: cyan),
                        )
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                          : controller != null &&
                                  controller.value.isInitialized
                              ? VideoPlayer(controller)
                              : Center(
                                  child: Text(
                                    tr('stream_error'),
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                                ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _initializePlayer,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(tr('retry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: liveRed,
                      foregroundColor: Colors.white,
                      elevation: 7,
                      shadowColor: liveRed,
                    ),
                  ),
                )
              else if (!_initializing &&
                  controller != null &&
                  controller.value.isInitialized)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => value.isPlaying
                          ? controller.pause()
                          : controller.play(),
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        value.isPlaying ? tr('pause') : tr('play'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: value.isPlaying ? panel : liveRed,
                        foregroundColor: Colors.white,
                        elevation: 7,
                        shadowColor: liveRed,
                      ),
                    ),
                  ),
                ),
            ],
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
  late final TextEditingController _channelController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _channelController = TextEditingController(text: channelSlug.value);
  }

  @override
  void dispose() {
    _channelController.dispose();
    super.dispose();
  }

  Future<void> _saveChannel() async {
    final slug = _channelController.text.trim();

    if (slug.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('invalid_channel'))),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ssh101_channel', slug);
      channelSlug.value = slug;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('saved'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la configuración.'),
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

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', languageCode(value));
    } catch (_) {
      // El idioma sigue activo en esta sesión si falla el almacenamiento.
    }

    if (mounted) setState(() {});
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('copy_done'))),
      );
    }
  }

  Widget _damianBanner() {
    return Container(
      height: 132,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xDD06152D),
            Color(0xCC15082D),
            Color(0xDD031E2B),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cyan.withValues(alpha: .9), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cyan.withValues(alpha: .26),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: pink.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const Positioned(
            left: 12,
            top: 10,
            child: Icon(
              Icons.sports_soccer_rounded,
              color: yellow,
              size: 24,
            ),
          ),
          const Positioned(
            right: 12,
            bottom: 10,
            child: Icon(
              Icons.bolt_rounded,
              color: green,
              size: 25,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'DAMIAN.APK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cyan,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: <Shadow>[
                      Shadow(
                        color: cyan,
                        blurRadius: 7,
                      ),
                      Shadow(
                        color: cyan,
                        blurRadius: 18,
                      ),
                      Shadow(
                        color: pink,
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 95,
                  height: 3,
                  decoration: BoxDecoration(
                    color: pink,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: pink, blurRadius: 9),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'DEPORTE TOTAL 360°',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slug = _channelController.text.trim();
    final valid =
        slug.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(slug);
    final rtmp = valid ? buildRtmpUrl(slug) : '$rtmpBase<TU_CANAL>';
    final hls =
        valid ? buildHlsUrl(slug) : '${hlsBase}<TU_CANAL>/playlist.m3u8';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          tr('settings'),
          style: const TextStyle(
            color: cyan,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: const Color(0xEE071B35),
      ),
      body: SettingsBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _damianBanner(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cyan.withValues(alpha: .8),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cyan.withValues(alpha: .12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr('language'),
                      style: const TextStyle(
                        color: cyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AppLanguage>(
                      value: appLanguage.value,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xDD06152D),
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
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel.withValues(alpha: .86),
                  borderRadius: BorderRadius.circular(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr('stream_setup'),
                      style: const TextStyle(
                        color: cyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('channel_slug'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _channelController,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: tr('channel_hint'),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: const Color(0xDD06152D),
                        prefixIcon: const Icon(Icons.live_tv_rounded),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      tr('settings_help'),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveChannel,
                        icon: const Icon(Icons.save_rounded),
                        label: Text(_saving ? '…' : tr('save')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: bg,
                          elevation: 8,
                          shadowColor: green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: tr('rtmp'),
                      value: rtmp,
                      onCopy: () => _copy(context, rtmp),
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      title: tr('hls'),
                      value: hls,
                      onCopy: () => _copy(context, hls),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('settings_help'),
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.45,
                  shadows: <Shadow>[
                    Shadow(color: bg, blurRadius: 8),
                  ],
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
      appBar: AppBar(title: Text(tr('support'))),
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
                  Icon(Icons.favorite_rounded, color: pink, size: 54),
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
                    'Esta sección queda preparada para añadir el enlace oficial de apoyo cuando esté disponible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.4),
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