import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'live_media_format.dart';

/// Diagnóstico de solo lectura. Conserva la URL y no cambia la región de red.
class StreamDiagnosticReport {
  const StreamDiagnosticReport({
    required this.title,
    required this.summary,
    required this.format,
    required this.host,
    this.sourceStatus,
    this.segmentStatus,
    this.contentType,
    this.possibleGeoRestriction = false,
    this.confirmedGeoRestriction = false,
    this.drmDetected = false,
    this.recommendation = '',
  });

  final String title;
  final String summary;
  final String format;
  final String host;
  final int? sourceStatus;
  final int? segmentStatus;
  final String? contentType;
  final bool possibleGeoRestriction;
  final bool confirmedGeoRestriction;
  final bool drmDetected;
  final String recommendation;

  String toDisplayString() {
    final lines = <String>[
      'RESULTADO: ' + title,
      summary,
      if (host.isNotEmpty) 'SERVIDOR: ' + host,
      'FORMATO: ' + format,
      if (sourceStatus != null) 'FUENTE: HTTP ' + sourceStatus.toString(),
      if (contentType != null) 'TIPO DE CONTENIDO: ' + contentType!,
      if (segmentStatus != null) 'PRIMER RECURSO HLS: HTTP ' + segmentStatus.toString(),
      if (possibleGeoRestriction && !confirmedGeoRestriction)
        'GEO: posible restricción regional. No se puede confirmar GeoIP solo con HTTP 403; también puede ser autenticación, token, Referer o política del servidor.',
      if (confirmedGeoRestriction) 'GEO: el proveedor indicó expresamente una limitación territorial.',
      if (drmDetected) 'DRM: el manifiesto anuncia protección de contenido o licencia.',
      if (recommendation.isNotEmpty) 'SIGUIENTE PASO: ' + recommendation,
      'Prueba orientativa; no modifica ni borra la URL original.',
    ];
    return lines.join('\n');
  }

  @override
  String toString() => toDisplayString();
}

class StreamDiagnosticsService {
  StreamDiagnosticsService({http.Client? client}) : _client = client ?? http.Client();

  static final StreamDiagnosticsService instance = StreamDiagnosticsService();
  final http.Client _client;
  static const _timeout = Duration(seconds: 9);
  static const _maxBytes = 65536;

  Future<StreamDiagnosticReport> diagnose(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') || uri.userInfo.isNotEmpty) {
      return const StreamDiagnosticReport(
        title: 'URL no válida',
        summary: 'No es una URL HTTP/HTTPS directa.',
        format: 'No identificado',
        host: '',
        recommendation: 'Revisa la dirección sin sustituirla automáticamente.',
      );
    }
    final format = liveMediaFormatForUrl(uri.toString());
    if (format == null) {
      return StreamDiagnosticReport(
        title: 'Formato no reconocido',
        summary: 'No se identificó un formato multimedia directo compatible.',
        format: 'No identificado',
        host: uri.host,
        recommendation: 'Confirma con el proveedor si la dirección es una URL multimedia directa.',
      );
    }

    try {
      final response = await _fetch(uri);
      final geo = _geo(response.status, response.body);
      final contentType = response.headers['content-type'];
      if (!_ok(response.status)) {
        return _failure(uri, format.name, response, geo);
      }

      if (format == LiveMediaFormat.hls) {
        if (!response.body.trimLeft().startsWith('#EXTM3U')) {
          final body = response.body.trimLeft().toLowerCase();
          final html = body.startsWith('<html') || body.startsWith('<!doctype');
          return StreamDiagnosticReport(
            title: html ? 'El servidor entregó HTML' : 'Manifiesto HLS inválido',
            summary: html
                ? 'La URL respondió una página web en vez de #EXTM3U; puede ser acceso, redirección o protección anti-bot.'
                : 'La respuesta no comienza con #EXTM3U.',
            format: 'HLS',
            host: uri.host,
            sourceStatus: response.status,
            contentType: contentType,
            possibleGeoRestriction: geo.possible,
            confirmedGeoRestriction: geo.confirmed,
            recommendation: 'Comprueba que sea la URL directa del manifiesto y si el proveedor exige sesión o cabeceras autorizadas.',
          );
        }
        final drm = _hlsDrm(response.body);
        final resource = _firstHlsResource(response.body);
        if (resource == null) {
          return StreamDiagnosticReport(
            title: 'Manifiesto HLS sin recursos visibles',
            summary: 'La lista se leyó, pero no se encontró una variante o segmento para comprobar.',
            format: 'HLS',
            host: uri.host,
            sourceStatus: response.status,
            contentType: contentType,
            drmDetected: drm,
            recommendation: 'Revisa el manifiesto con el proveedor.',
          );
        }
        final internal = await _fetch(uri.resolve(resource));
        final internalGeo = _geo(internal.status, internal.body);
        return StreamDiagnosticReport(
          title: !_ok(internal.status)
              ? 'Manifiesto accesible; primer recurso rechazado'
              : drm
                  ? 'HLS accesible con protección de contenido'
                  : 'Fuente HLS accesible',
          summary: !_ok(internal.status)
              ? 'El manifiesto responde, pero su primera variante o segmento devolvió HTTP ' + internal.status.toString() + '.'
              : 'Se leyó el manifiesto y se comprobó el primer recurso. Esto no garantiza que toda la transmisión esté disponible.',
          format: 'HLS',
          host: uri.host,
          sourceStatus: response.status,
          segmentStatus: internal.status,
          contentType: contentType,
          possibleGeoRestriction: geo.possible || internalGeo.possible,
          confirmedGeoRestriction: geo.confirmed || internalGeo.confirmed,
          drmDetected: drm,
          recommendation: internal.status == 403
              ? 'El recurso puede exigir autorización, token, Referer o acceso regional. HTTP 403 no prueba GeoIP.'
              : drm
                  ? 'Solicita autorización/licencia al proveedor. AES-128 HLS no implica necesariamente DRM.'
                  : 'Si el reproductor falla, revisa códec, formato, cabeceras autorizadas y compatibilidad Android.',
        );
      }

      if (format == LiveMediaFormat.dash) {
        final drm = RegExp(r'ContentProtection|widevine|playready|urn:uuid',
          caseSensitive: false).hasMatch(response.body);
        return StreamDiagnosticReport(
          title: drm ? 'DASH accesible con DRM' : 'Manifiesto DASH accesible',
          summary: drm
              ? 'El manifiesto anuncia protección de contenido y puede exigir licencia válida.'
              : 'El servidor respondió; el reproductor aún debe leer los segmentos.',
          format: 'DASH',
          host: uri.host,
          sourceStatus: response.status,
          contentType: contentType,
          drmDetected: drm,
          possibleGeoRestriction: geo.possible,
          confirmedGeoRestriction: geo.confirmed,
          recommendation: drm
              ? 'Solicita la licencia al proveedor; no se intenta eludir DRM.'
              : 'Comprueba segmentos y compatibilidad si persiste el error.',
        );
      }

      return StreamDiagnosticReport(
        title: 'Servidor accesible',
        summary: 'La dirección respondió. El fallo puede estar en el contenedor, códec o decodificador del teléfono.',
        format: format.name.toUpperCase(),
        host: uri.host,
        sourceStatus: response.status,
        contentType: contentType,
        possibleGeoRestriction: geo.possible,
        confirmedGeoRestriction: geo.confirmed,
        recommendation: 'Comprueba el códec y prueba la misma fuente en otro reproductor Android.',
      );
    } on TimeoutException {
      return StreamDiagnosticReport(
        title: 'Tiempo de espera agotado',
        summary: 'El servidor o recurso no respondió dentro del límite de prueba.',
        format: format.name.toUpperCase(),
        host: uri.host,
        recommendation: 'Comprueba la conexión y vuelve a probar. No se concluye que sea GeoIP.',
      );
    } catch (error) {
      final message = error.toString().toLowerCase();
      final tls = message.contains('ssl') || message.contains('certificate') ||
          message.contains('handshake');
      return StreamDiagnosticReport(
        title: tls ? 'Error de certificado TLS' : 'No se pudo conectar',
        summary: tls ? 'Falló la validación de la conexión segura.' : 'No se pudo completar la prueba: ' + error.toString(),
        format: format.name.toUpperCase(),
        host: uri.host,
        recommendation: tls ? 'Comprueba fecha/hora y certificado del servidor.' : 'Comprueba Internet y disponibilidad del servidor.',
      );
    }
  }

  Future<_Probe> _fetch(Uri uri) async {
    final request = http.Request('GET', uri)
      ..headers.addAll(<String, String>{
        'Accept': '*/*',
        'Range': 'bytes=0-65535',
      });
    final response = await _client.send(request).timeout(_timeout);
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(_timeout)) {
      final remaining = _maxBytes - bytes.length;
      if (remaining > 0) bytes.addAll(chunk.take(remaining));
      if (bytes.length >= _maxBytes) break;
    }
    return _Probe(
      response.statusCode,
      response.headers.map((key, value) => MapEntry(key.toLowerCase(), value)),
      utf8.decode(bytes, allowMalformed: true),
    );
  }

  String? _firstHlsResource(String body) {
    final lines = body.split(RegExp(r'\r?\n')).map((line) => line.trim())
        .where((line) => line.isNotEmpty).toList();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
        for (var j = i + 1; j < lines.length; j++) {
          if (!lines[j].startsWith('#')) return lines[j];
        }
      }
    }
    for (final line in lines) {
      if (!line.startsWith('#')) return line;
    }
    return null;
  }

  bool _hlsDrm(String body) => body.split(RegExp(r'\r?\n')).any((line) {
    final value = line.toUpperCase();
    return value.contains('#EXT-X-KEY') &&
      (value.contains('METHOD=SAMPLE-AES') ||
       (value.contains('KEYFORMAT=') && !value.contains('KEYFORMAT="IDENTITY"') &&
        !value.contains("KEYFORMAT='IDENTITY'")));
  });

  _Geo _geo(int status, String body) {
    final explicit = RegExp(
      r'geo.?block|not available in (your )?(country|region)|country not supported|region not supported|outside (of )?(your )?(country|territory)|territorial restriction|unavailable in your location|no disponible en (tu|su) (pa[ií]s|regi[oó]n)|restricci[oó]n geogr[aá]fica',
    ).hasMatch(body.toLowerCase());
    return _Geo(status == 403 || status == 451 || explicit,
      status == 451 || explicit);
  }

  bool _ok(int status) => status == 200 || status == 206;

  StreamDiagnosticReport _failure(Uri uri, String format, _Probe p, _Geo geo) {
    final status = p.status;
    final title = switch (status) {
      401 => 'Acceso no autorizado (401)',
      403 => geo.confirmed ? 'Restricción regional indicada por el proveedor' : 'Acceso denegado (403)',
      404 || 410 => 'Fuente no encontrada (' + status.toString() + ')',
      429 => 'Límite de solicitudes (429)',
      451 => 'Restricción legal o territorial (451)',
      >= 500 => 'Servidor no disponible (' + status.toString() + ')',
      _ => 'Respuesta HTTP ' + status.toString(),
    };
    final summary = switch (status) {
      401 => 'El proveedor exige autenticación, sesión o credenciales.',
      403 => geo.confirmed
          ? 'La respuesta indica expresamente una limitación territorial.'
          : 'El servidor rechazó la petición. Puede ser región, cuenta, token, Referer, User-Agent o política anti-bot; HTTP 403 no confirma GeoIP.',
      404 || 410 => 'El recurso no existe o fue retirado.',
      429 => 'El servidor limita las solicitudes.',
      451 => 'El servidor informa una limitación legal o territorial.',
      >= 500 => 'El servidor informó un error temporal o interno.',
      _ => 'La respuesta no permite continuar el diagnóstico.',
    };
    return StreamDiagnosticReport(
      title: title,
      summary: summary,
      format: format.toUpperCase(),
      host: uri.host,
      sourceStatus: status,
      contentType: p.headers['content-type'],
      possibleGeoRestriction: geo.possible,
      confirmedGeoRestriction: geo.confirmed,
      recommendation: switch (status) {
        401 => 'Solicita acceso legítimo o renueva la autorización.',
        403 => 'Verifica las condiciones y cabeceras autorizadas por el proveedor; no se cambia la región de conexión.',
        404 || 410 => 'Solicita una URL vigente y conserva la original hasta verificar otra fuente.',
        429 => 'Espera antes de volver a probar; evita reintentos continuos.',
        451 => 'Usa una señal autorizada para tu región o solicita acceso.',
        >= 500 => 'Prueba más tarde o usa otra fuente autorizada.',
        _ => 'Revisa las condiciones de acceso con el proveedor.',
      },
    );
  }
}

class _Probe {
  const _Probe(this.status, this.headers, this.body);
  final int status;
  final Map<String, String> headers;
  final String body;
}
class _Geo {
  const _Geo(this.possible, this.confirmed);
  final bool possible;
  final bool confirmed;
}

String explainVideoPlayerError(Object error) {
  final raw = error.toString();
  final value = raw.toLowerCase();
  final explanation = value.contains('yb0') || value.contains('source error')
      ? 'El reproductor no pudo cargar la fuente o uno de sus segmentos. Puede ser URL vencida, HTTP denegado, manifiesto/segmentos inaccesibles, cabeceras requeridas o formato incompatible. yb0 no identifica por sí solo la causa.'
      : value.contains('403') || value.contains('forbidden')
          ? 'El servidor denegó el acceso. Puede ser autorización, token, cabeceras o región; no confirma GeoIP.'
          : value.contains('404') || value.contains('not found')
              ? 'La fuente o uno de sus recursos no fue encontrado.'
              : value.contains('timeout')
                  ? 'La fuente no respondió a tiempo.'
                  : value.contains('ssl') || value.contains('certificate')
                      ? 'Falló la conexión segura o su certificado.'
                      : value.contains('drm') || value.contains('license')
                          ? 'La señal puede requerir licencia DRM o autorización.'
                          : 'El reproductor no pudo iniciar esta señal.';
  final detail = raw.length > 360 ? raw.substring(0, 357) + '…' : raw;
  return explanation + '\nDetalle técnico: ' + detail;
}

class StreamDiagnosticButton extends StatefulWidget {
  const StreamDiagnosticButton({
    super.key,
    required this.url,
    this.compact = false,
    this.color = const Color(0xFF00A3FF),
  });
  final String url;
  final bool compact;
  final Color color;
  @override
  State<StreamDiagnosticButton> createState() => _StreamDiagnosticButtonState();
}
class _StreamDiagnosticButtonState extends State<StreamDiagnosticButton> {
  bool _running = false;
  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final report = await StreamDiagnosticsService.instance.diagnose(widget.url);
    if (!mounted) return;
    setState(() => _running = false);
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF07090D),
      title: Text('DIAGNÓSTICO DE TRANSMISIÓN', style: TextStyle(
        color: widget.color, fontWeight: FontWeight.w900, fontSize: 15)),
      content: SingleChildScrollView(child: SelectableText(report.toDisplayString(),
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5))),
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(ctx).pop(),
        child: Text('CERRAR', style: TextStyle(color: widget.color)))],
    ));
  }
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _running ? null : _run,
    icon: _running ? SizedBox(width: 14, height: 14, child:
      CircularProgressIndicator(strokeWidth: 2, color: widget.color))
      : Icon(Icons.travel_explore_rounded, size: widget.compact ? 14 : 18),
    label: Text(_running ? 'DIAGNOSTICANDO...' :
      widget.compact ? 'DIAGNÓSTICO' : 'DIAGNOSTICAR TRANSMISIÓN / GEO',
      style: TextStyle(fontSize: widget.compact ? 9 : 11, fontWeight: FontWeight.w900)),
    style: TextButton.styleFrom(foregroundColor: widget.color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 10,
        vertical: widget.compact ? 2 : 7)),
  );
}
