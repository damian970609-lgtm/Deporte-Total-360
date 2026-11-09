import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_section_design.dart';

const String installedAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.5',
);
const String installedAppBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '0',
);

const Color _updateBackground = Color(0xFF000000);
const Color _updatePanel = Color(0xFF080D15);
const Color _updateBlue = Color(0xFF00A3FF);
const Color _updateGreen = Color(0xFF39FF14);
const Color _updateRed = Color(0xFFFF1744);
const Color _updateText = Color(0xFFEAF0F8);

const String _latestReleaseApi =
    'https://api.github.com/repos/damian970609-lgtm/Deporte-Total-360/releases/latest';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key, this.client});

  final http.Client? client;

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  late final http.Client _client = widget.client ?? http.Client();
  late final bool _ownsClient = widget.client == null;

  bool _checking = false;
  bool? _updateAvailable;
  String _message = 'Comprobando la última versión publicada…';
  String? _latestTag;
  String? _downloadUrl;
  String? _releasePageUrl;

  _VersionStamp get _installedStamp => _VersionStamp(
        installedAppVersion,
        int.tryParse(installedAppBuildNumber) ?? 0,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForUpdates();
    });
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }

  String? _httpsUrl(dynamic value) {
    final uri = Uri.tryParse((value ?? '').toString().trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = 'Buscando la publicación oficial más reciente…';
    });

    try {
      final result = await _client
          .get(
            Uri.parse(_latestReleaseApi),
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Deporte-Total-360-Android',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (result.statusCode == 404) {
        if (!mounted) return;
        setState(() {
          _updateAvailable = false;
          _latestTag = null;
          _downloadUrl = null;
          _releasePageUrl = null;
          _message =
              'Todavía no hay una publicación oficial disponible. Esta sección se activará cuando se publique una nueva APK.';
        });
        return;
      }

      if (result.statusCode != 200) {
        throw FormatException(
          'GitHub respondió con el código ' + result.statusCode.toString() + '.',
        );
      }

      final decoded = jsonDecode(result.body);
      if (decoded is! Map) {
        throw const FormatException('La respuesta de GitHub no es válida.');
      }
      final release = Map<String, dynamic>.from(decoded);
      final tag = (release['tag_name'] ?? '').toString().trim();
      final latestStamp = _VersionStamp.parse(tag);
      if (latestStamp == null) {
        throw const FormatException(
          'La publicación más reciente no tiene una versión reconocible.',
        );
      }

      String? apkUrl;
      final assets = release['assets'];
      if (assets is List) {
        for (final rawAsset in assets.whereType<Map>()) {
          final asset = Map<String, dynamic>.from(rawAsset);
          final assetName = (asset['name'] ?? '').toString().trim().toLowerCase();
          final assetLabel = (asset['label'] ?? '').toString().trim().toLowerCase();
          if (assetName == 'deporte-total-360.apk' ||
              assetLabel == 'deporte-total-360.apk') {
            apkUrl = _httpsUrl(asset['browser_download_url']);
            if (apkUrl != null) break;
          }
        }
      }

      final pageUrl = _httpsUrl(release['html_url']);
      final available = latestStamp.compareTo(_installedStamp) > 0;

      if (!mounted) return;
      setState(() {
        _updateAvailable = available;
        _latestTag = tag;
        _downloadUrl = apkUrl;
        _releasePageUrl = pageUrl;
        _message = available
            ? 'Hay una versión más reciente publicada.'
            : 'Esta APK ya está al día con la última versión oficial.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _updateAvailable = null;
        _message =
            'No se pudo comprobar la actualización. Revisa la conexión a Internet y vuelve a intentarlo. ' +
                (error is FormatException ? error.message : '');
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openDownload() async {
    final target = _downloadUrl ?? _releasePageUrl;
    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La publicación no contiene un enlace de descarga válido.'),
          ),
        );
      }
      return;
    }

    try {
      final opened = await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Android no pudo abrir la descarga.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la descarga.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = '$installedAppVersion+$installedAppBuildNumber';
    final statusColor = _updateAvailable == true
        ? _updateGreen
        : _updateAvailable == false
            ? _updateBlue
            : _updateRed;
    final statusIcon = _updateAvailable == true
        ? Icons.system_update_alt_rounded
        : _updateAvailable == false
            ? Icons.verified_rounded
            : Icons.cloud_sync_rounded;

    return Scaffold(
      backgroundColor: _updateBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AppSectionTitle(
                icon: Icons.system_update_alt_rounded,
                title: 'ACTUALIZACIÓN',
                subtitle: 'CONTROL DE VERSIONES Y DESCARGA OFICIAL',
                accent: _updateBlue,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _updatePanel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _updateBlue.withAlpha(180)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'VERSIÓN INSTALADA',
                      style: TextStyle(
                        color: _updateBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      installed,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Número de versión y compilación de esta instalación.',
                      style: TextStyle(
                        color: _updateText,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _updatePanel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: statusColor.withAlpha(180)),
                ),
                child: Column(
                  children: <Widget>[
                    if (_checking)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      Icon(statusIcon, color: statusColor, size: 34),
                    const SizedBox(height: 9),
                    Text(
                      _checking
                          ? 'COMPROBANDO VERSIÓN'
                          : _updateAvailable == true
                              ? 'NUEVA VERSIÓN DISPONIBLE'
                              : _updateAvailable == false
                                  ? 'ESTADO DE LA APLICACIÓN'
                                  : 'COMPROBACIÓN PENDIENTE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _updateText,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    if (_latestTag != null) ...<Widget>[
                      const SizedBox(height: 9),
                      Text(
                        'Publicación: $_latestTag',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _updateBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_updateAvailable == true)
                FilledButton.icon(
                  onPressed: _checking ? null : _openDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    _downloadUrl == null
                        ? 'ABRIR PUBLICACIÓN'
                        : 'DESCARGAR APK',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _updateGreen,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _checking ? null : _checkForUpdates,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    _checking ? 'COMPROBANDO…' : 'COMPROBAR ACTUALIZACIONES',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _updateBlue,
                    side: const BorderSide(color: _updateBlue),
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF263243)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'INSTALACIÓN SEGURA',
                      style: TextStyle(
                        color: _updateBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'La descarga se abre en el navegador y Android solicita confirmar la instalación. Instala la APK encima de la versión actual; no desinstales la aplicación para conservar tus listas y preferencias.',
                      style: TextStyle(
                        color: _updateText,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'La comprobación consulta GitHub Releases. No utiliza la cuota de Cloudflare ni de SportsAPI.',
                      style: TextStyle(
                        color: _updateText,
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
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

class _VersionStamp implements Comparable<_VersionStamp> {
  const _VersionStamp(this.version, this.build);

  final String version;
  final int build;

  static _VersionStamp? parse(String raw) {
    final match = RegExp(r'^v?(\d+(?:\.\d+){1,3})(?:\+(\d+))?$')
        .firstMatch(raw.trim());
    if (match == null) return null;
    return _VersionStamp(
      match.group(1)!,
      int.tryParse(match.group(2) ?? '0') ?? 0,
    );
  }

  @override
  int compareTo(_VersionStamp other) {
    final left = version.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final right = other.version.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      if (a != b) return a.compareTo(b);
    }
    return build.compareTo(other.build);
  }
}
