import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_i18n.dart';

const Color _summaryBg = Color(0xFF030814);
const Color _summaryPanel = Color(0xFF071326);
const Color _summaryLine = Color(0xFF123D65);
const Color _summaryCyan = Color(0xFF00E5FF);
const Color _summaryPink = Color(0xFFFF28CF);
const Color _summaryMuted = Color(0xFFA9BDD6);

class _SummaryCategory {
  const _SummaryCategory(this.name, this.query, this.icon, this.color);

  final String name;
  final String query;
  final IconData icon;
  final Color color;
}

/// Abre búsquedas de resúmenes y mejores jugadas en YouTube.
/// El vídeo lo sirve su canal original; la aplicación no descarga ni redistribuye contenido.
class SportsSummariesScreen extends StatelessWidget {
  const SportsSummariesScreen({super.key});

  static const List<_SummaryCategory> _categories = <_SummaryCategory>[
    _SummaryCategory('Fútbol', 'resumenes futbol partidos oficiales', Icons.sports_soccer_rounded, _summaryCyan),
    _SummaryCategory('NBA', 'NBA official highlights', Icons.sports_basketball_rounded, _summaryPink),
    _SummaryCategory('Béisbol', 'MLB official highlights', Icons.sports_baseball_rounded, _summaryCyan),
    _SummaryCategory('NFL', 'NFL official highlights', Icons.sports_football_rounded, _summaryPink),
    _SummaryCategory('Fórmula 1', 'Formula 1 official race highlights', Icons.sports_motorsports_rounded, _summaryCyan),
    _SummaryCategory('MMA / UFC', 'UFC official fight highlights', Icons.sports_mma_rounded, _summaryPink),
    _SummaryCategory('Rugby', 'rugby official match highlights', Icons.sports_rugby_rounded, _summaryCyan),
    _SummaryCategory('Vóley', 'volleyball official match highlights', Icons.sports_volleyball_rounded, _summaryPink),
  ];

  Future<void> _openSearch(BuildContext context, _SummaryCategory category) async {
    final uri = Uri.https(
      'www.youtube.com',
      '/results',
      <String, String>{'search_query': category.query},
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(
            'No se pudo abrir YouTube. Comprueba que tengas conexión.',
            'Could not open YouTube. Check your connection.',
            'Não foi possível abrir o YouTube. Verifique sua conexão.',
            'Impossible d’ouvrir YouTube. Vérifiez votre connexion.',
          ))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(
            'No se pudo abrir la búsqueda de resúmenes.',
            'Could not open the highlights search.',
            'Não foi possível abrir a busca de resumos.',
            'Impossible d’ouvrir la recherche de résumés.',
          ))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _summaryBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: Text(
          appText('RESÚMENES DEPORTIVOS', 'SPORTS HIGHLIGHTS', 'RESUMOS ESPORTIVOS', 'RÉSUMÉS SPORTIFS'),
          style: const TextStyle(
            color: _summaryCyan,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _summaryPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _summaryLine),
            ),
            child: Text(
              appText(
                'Encuentra resúmenes, goles y mejores jugadas por deporte. Se abrirán resultados de YouTube de los canales que publican cada vídeo.',
                'Find match recaps, goals and highlights by sport. YouTube results from the channels publishing each video will open.',
                'Encontre resumos, gols e melhores jogadas por esporte. Serão abertos resultados do YouTube dos canais que publicam cada vídeo.',
                'Trouvez des résumés, des buts et les meilleurs moments par sport. Les résultats YouTube des chaînes qui publient chaque vidéo s’ouvriront.',
              ),
              style: const TextStyle(color: _summaryMuted, height: 1.45, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          for (final category in _categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: _summaryPanel,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => _openSearch(context, category),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: category.color.withAlpha(150)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(category.icon, color: category.color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.play_circle_outline_rounded, color: _summaryCyan),
                      ],
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
