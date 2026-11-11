import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String _protonAndroidPackage = 'ch.protonvpn.android';
const String _protonPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=ch.protonvpn.android';
const String _protonOfficialDownloadUrl =
    'https://protonvpn.com/download-android';

const Color _protonBg = Color(0xFF000000);
const Color _protonPanel = Color(0xFF07090D);
const Color _protonPanel2 = Color(0xFF0D1118);
const Color _protonBlue = Color(0xFF00A3FF);
const Color _protonGreen = Color(0xFF39FF14);
const Color _protonMuted = Color(0xFFEAF0F8);
const Color _protonLine = Color(0xFF0047FF);

/// Integración de Proton VPN mediante su aplicación oficial de Android.
/// La conexión y la selección del servidor siguen bajo el control de Proton.
class ProtonVpnScreen extends StatelessWidget {
  const ProtonVpnScreen({super.key});

  Future<void> _openProton(BuildContext context) async {
    if (Platform.isAndroid) {
      try {
        await const AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: _protonAndroidPackage,
        ).launch();
        return;
      } catch (_) {
        // Si Proton no está instalado, se ofrece su ficha oficial de Google Play.
      }
    }
    if (!context.mounted) return;
    await _openStore(context);
  }

  Future<void> _openStore(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.parse(_protonPlayStoreUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir Google Play. Usa el enlace oficial de Proton VPN.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir Proton VPN: $error')),
        );
      }
    }
  }

  Future<void> _openOfficialDownload(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.parse(_protonOfficialDownloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la página oficial de Proton.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la página de Proton: $error')),
        );
      }
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _protonPanel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _protonLine.withAlpha(190)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: _protonBlue.withAlpha(16), blurRadius: 15),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _protonBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.shield_rounded, color: _protonBlue, size: 23),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'PROTON VPN · CONEXIÓN PROTEGIDA',
                          style: TextStyle(
                            color: _protonBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Proton es el proveedor VPN principal de Deporte Total 360°. La conexión se activa en la aplicación oficial de Proton; esta APK no guarda tu contraseña ni tus claves VPN.',
                    style: TextStyle(
                      color: _protonMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openProton(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('ABRIR PROTON VPN'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _protonBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openStore(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('INSTALAR O ACTUALIZAR PROTON'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => _openOfficialDownload(context),
                      child: const Text(
                        'DESCARGA OFICIAL DE PROTON',
                        style: TextStyle(
                          color: _protonBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'CÓMO PROTEGER LOS REPRODUCTORES',
                    style: TextStyle(
                      color: _protonGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const _ProtonStep(
                    number: '1',
                    title: 'Abre Proton VPN',
                    description: 'Inicia sesión o crea tu cuenta directamente en Proton.',
                  ),
                  const _ProtonStep(
                    number: '2',
                    title: 'Conecta la VPN',
                    description: 'Usa la conexión rápida o el servidor que Proton permita en tu plan.',
                  ),
                  const _ProtonStep(
                    number: '3',
                    title: 'Regresa a Deporte Total 360°',
                    description: 'Si Deporte Total 360° no está excluida en Proton, los tres reproductores utilizan automáticamente esa conexión de Android.',
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _protonPanel2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _protonGreen.withAlpha(120)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.info_outline_rounded, color: _protonGreen, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Comprueba el icono de VPN o llave en la barra de Android. Esta integración externa no puede leer el estado interno de Proton.',
                            style: TextStyle(
                              color: _protonMuted,
                              fontSize: 10,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _card(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LÍMITES IMPORTANTES DE ANDROID',
                    style: TextStyle(
                      color: _protonBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La aplicación oficial de Proton crea una VPN a nivel de Android. Por eso protege el tráfico de toda Deporte Total 360°: no puede activarse solo para un canal y dejar los otros dos reproductores fuera del túnel.',
                    style: TextStyle(color: _protonMuted, fontSize: 10, height: 1.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La APK no cambia países en busca de señales bloqueadas ni elimina restricciones regionales. Proton controla sus servidores, ubicaciones disponibles y selección automática.',
                    style: TextStyle(color: _protonMuted, fontSize: 10, height: 1.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La VPN mejora la privacidad de la conexión, pero no garantiza que una señal funcione: el canal también debe estar disponible y autorizado para tu ubicación.',
                    style: TextStyle(color: _protonMuted, fontSize: 10, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtonStep extends StatelessWidget {
  const _ProtonStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _protonBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: _protonMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
