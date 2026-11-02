import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_i18n.dart';
import 'sports_api_service.dart';

const Color _chatBg = Color(0xFF030814);
const Color _chatPanel = Color(0xFF071326);
const Color _chatCyan = Color(0xFF00E5FF);
const Color _chatGreen = Color(0xFF39FF9C);
const Color _chatPink = Color(0xFFFF28CF);
const Color _chatMuted = Color(0xFFA9BDD6);
const String _chatBackgroundAsset =
    'assets/images/file_000000006048820e9e0720f1adf548f1.png';

class PublicChatMessage {
  const PublicChatMessage({
    required this.id,
    required this.name,
    required this.text,
    required this.createdAt,
    required this.language,
  });

  final String id;
  final String name;
  final String text;
  final DateTime createdAt;
  final String language;

  factory PublicChatMessage.fromJson(Map<String, dynamic> json) {
    final rawLanguage = (json['language'] ?? 'es').toString();
    return PublicChatMessage(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Invitado').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
      language: const <String>{'es', 'en', 'pt', 'fr'}.contains(rawLanguage)
          ? rawLanguage
          : 'es',
    );
  }
}

class PublicChatService {
  static const int maxNameLength = 24;
  static const int maxMessageLength = 500;
  static const Duration timeout = Duration(seconds: 12);

  Uri _messagesUri() {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw Exception(appText(
        'El servidor del chat no está configurado.',
        'The chat server is not configured.',
        'O servidor do chat não está configurado.',
        'Le serveur de discussion n’est pas configuré.',
      ));
    }
    return Uri.parse(base + '/api/chat/messages');
  }

  Future<List<PublicChatMessage>> loadMessages() async {
    final response = await http.get(_messagesUri()).timeout(timeout);
    if (response.statusCode != 200) throw _responseError(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['messages'] is! List) {
      throw Exception(appText(
        'El servidor devolvió una respuesta de chat inválida.',
        'The server returned an invalid chat response.',
        'O servidor retornou uma resposta de chat inválida.',
        'Le serveur a renvoyé une réponse de discussion invalide.',
      ));
    }
    return (decoded['messages'] as List)
        .whereType<Map>()
        .map((item) => PublicChatMessage.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((message) => message.id.isNotEmpty && message.text.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<PublicChatMessage> sendMessage({
    required String name,
    required String text,
    required String language,
  }) async {
    final response = await http
        .post(
          _messagesUri(),
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, String>{
            'name': name.trim(),
            'text': text.trim(),
            'language': language,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 201) throw _responseError(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['message'] is! Map) {
      throw Exception(appText(
        'No se pudo confirmar el mensaje enviado.',
        'The sent message could not be confirmed.',
        'Não foi possível confirmar a mensagem enviada.',
        'Impossible de confirmer le message envoyé.',
      ));
    }
    return PublicChatMessage.fromJson(
      Map<String, dynamic>.from(decoded['message'] as Map),
    );
  }

  Exception _responseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return Exception(decoded['error'].toString());
      }
    } catch (_) {}
    if (response.statusCode == 429) {
      return Exception(appText(
        'Espera un momento antes de volver a enviar.',
        'Please wait before sending another message.',
        'Aguarde um momento antes de enviar novamente.',
        'Veuillez patienter avant de renvoyer un message.',
      ));
    }
    return Exception('HTTP ' + response.statusCode.toString());
  }
}

class PublicChatTranslationService {
  static const Duration timeout = Duration(seconds: 9);

  /// El texto original queda guardado en el chat; solo se traduce su copia
  /// visible en el dispositivo que solicita la traducción.
  Future<String?> translate({
    required String text,
    required String source,
    required String target,
  }) async {
    if (source == target) return text;
    const supported = <String>{'es', 'en', 'pt', 'fr'};
    if (!supported.contains(source) || !supported.contains(target)) return null;
    if (utf8.encode(text).length > 500) return null;

    final uri = Uri.https(
      'api.mymemory.translated.net',
      '/get',
      <String, String>{
        'q': text,
        'langpair': '$source|$target',
        'mt': '1',
      },
    );
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['responseData'] is! Map) return null;
    if (decoded['responseStatus']?.toString() != '200') return null;
    final data = Map<String, dynamic>.from(decoded['responseData'] as Map);
    final translated = (data['translatedText'] ?? '').toString().trim();
    if (translated.isEmpty || translated == text) return null;
    return translated;
  }
}

class PublicChatScreen extends StatefulWidget {
  const PublicChatScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<PublicChatScreen> createState() => _PublicChatScreenState();
}

class _PublicChatScreenState extends State<PublicChatScreen> {
  final PublicChatService _service = PublicChatService();
  final PublicChatTranslationService _translationService =
      PublicChatTranslationService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();

  Timer? _pollTimer;
  List<PublicChatMessage> _messages = <PublicChatMessage>[];
  final Map<String, String> _translatedTexts = <String, String>{};
  final Set<String> _translationPending = <String>{};
  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;
  bool _autoTranslate = true;
  String? _error;
  String? _translationCacheLanguage;

  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_onChatLanguageChanged);
    if (widget.isActive) _activateChat();
  }

  @override
  void didUpdateWidget(covariant PublicChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activateChat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _activateChat() {
    unawaited(_loadSavedPreferences());
    unawaited(_refreshMessages());
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshMessages(silent: true),
    );
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('public_chat_nickname') ?? '';
      final autoTranslate =
          prefs.getBool('public_chat_auto_translate') ?? true;
      if (!mounted) return;
      setState(() {
        if (_nameController.text.isEmpty) _nameController.text = savedName;
        _autoTranslate = autoTranslate;
      });
      await _loadTranslationCache(languageCode(appLanguage.value));
      if (_autoTranslate) {
        unawaited(_translateRecentMessages(_messages));
      }
    } catch (_) {}
  }

  Future<void> _loadTranslationCache(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('public_chat_translations_' + language);
      final decoded = raw == null ? null : jsonDecode(raw);
      final cached = <String, String>{};
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.key is String && entry.value is String) {
            cached[entry.key.toString()] = entry.value.toString();
          }
        }
      }
      if (!mounted || language != languageCode(appLanguage.value)) return;
      setState(() {
        _translatedTexts
          ..clear()
          ..addAll(cached);
        _translationCacheLanguage = language;
      });
    } catch (_) {
      _translationCacheLanguage = language;
    }
  }

  void _onChatLanguageChanged() {
    final target = languageCode(appLanguage.value);
    setState(() {
      _translatedTexts.clear();
      _translationCacheLanguage = null;
    });
    unawaited(_loadTranslationCache(target).then((_) {
      if (mounted && widget.isActive && _autoTranslate) {
        return _translateRecentMessages(_messages);
      }
    }));
  }

  Future<void> _translateRecentMessages(
    List<PublicChatMessage> messages,
  ) async {
    if (!_autoTranslate || messages.isEmpty || !widget.isActive) return;
    final target = languageCode(appLanguage.value);
    if (_translationCacheLanguage != target) {
      await _loadTranslationCache(target);
    }

    // El caché local evita traducir repetidamente cada mensaje en cada sondeo.
    final recent = messages.reversed.take(12).toList(growable: false);
    for (final message in recent) {
      if (!_autoTranslate ||
          !mounted ||
          target != languageCode(appLanguage.value)) {
        return;
      }
      if (message.language == target ||
          _translatedTexts.containsKey(message.id) ||
          !_translationPending.add(message.id)) {
        continue;
      }
      try {
        final translated = await _translationService.translate(
          text: message.text,
          source: message.language,
          target: target,
        );
        if (translated != null &&
            mounted &&
            target == languageCode(appLanguage.value)) {
          setState(() => _translatedTexts[message.id] = translated);
        }
      } catch (_) {
        // El mensaje original permanece visible si el proveedor no responde.
      } finally {
        _translationPending.remove(message.id);
      }
    }

    if (!mounted || target != languageCode(appLanguage.value)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _translatedTexts.entries.toList(growable: false);
      final limited = entries.length > 100
          ? entries.sublist(entries.length - 100)
          : entries;
      await prefs.setString(
        'public_chat_translations_' + target,
        jsonEncode(Map<String, String>.fromEntries(limited)),
      );
      _translationCacheLanguage = target;
    } catch (_) {}
  }

  Future<void> _toggleAutoTranslate() async {
    final next = !_autoTranslate;
    setState(() => _autoTranslate = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('public_chat_auto_translate', next);
    } catch (_) {}
    if (next) unawaited(_translateRecentMessages(_messages));
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onChatLanguageChanged);
    _pollTimer?.cancel();
    _nameController.dispose();
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshMessages({bool silent = false}) async {
    if (_refreshing || !widget.isActive) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final messages = await _service.loadMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
      if (_autoTranslate) {
        unawaited(_translateRecentMessages(messages));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _messages.isEmpty) _error = error.toString();
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _sendMessage() async {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();

    if (name.length < 2) {
      _showMessage(appText(
        'Escribe un nombre de al menos 2 caracteres.',
        'Enter a name with at least 2 characters.',
        'Digite um nome com pelo menos 2 caracteres.',
        'Saisissez un nom d’au moins 2 caractères.',
      ));
      return;
    }
    if (message.isEmpty) {
      _showMessage(appText(
        'Escribe un mensaje antes de enviarlo.',
        'Write a message before sending it.',
        'Escreva uma mensagem antes de enviar.',
        'Écrivez un message avant de l’envoyer.',
      ));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('public_chat_nickname', name);
      final sent = await _service.sendMessage(
        name: name,
        text: message,
        language: languageCode(appLanguage.value),
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((item) => item.id == sent.id)) {
          _messages = <PublicChatMessage>[..._messages, sent];
        }
        _messageController.clear();
        _sending = false;
      });
      _messageFocus.unfocus();
      await _refreshMessages(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showMessage(error.toString());
    }
  }

  void _showMessage(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return local.hour.toString().padLeft(2, '0') +
        ':' +
        local.minute.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final newestFirst = _messages.reversed.toList(growable: false);
    return Scaffold(
      backgroundColor: _chatBg,
      appBar: AppBar(
        backgroundColor: _chatBg.withAlpha(235),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr('public_chat'),
              style: const TextStyle(
                color: _chatCyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                shadows: <Shadow>[Shadow(color: _chatCyan, blurRadius: 7)],
              ),
            ),
            Text(
              tr('public_chat_online'),
              style: const TextStyle(
                color: _chatGreen,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _autoTranslate
                ? appText('Desactivar traducción automática',
                    'Disable automatic translation',
                    'Desativar tradução automática',
                    'Désactiver la traduction automatique')
                : appText('Activar traducción automática',
                    'Enable automatic translation',
                    'Ativar tradução automática',
                    'Activer la traduction automatique'),
            onPressed: _toggleAutoTranslate,
            icon: Icon(
              Icons.translate_rounded,
              color: _autoTranslate ? _chatGreen : _chatMuted,
            ),
          ),
          IconButton(
            tooltip: appText('Actualizar mensajes', 'Refresh messages',
                'Atualizar mensagens', 'Actualiser les messages'),
            onPressed: () => _refreshMessages(),
            icon: const Icon(Icons.refresh_rounded, color: _chatCyan),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.24,
                child: Image.asset(
                  _chatBackgroundAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0xCC030814)),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _chatPanel.withAlpha(225),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _chatCyan.withAlpha(160)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: _chatCyan.withAlpha(24), blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.account_circle_rounded,
                          color: _chatCyan, size: 24),
                      const SizedBox(width: 9),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          maxLength: PublicChatService.maxNameLength,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: tr('public_chat_name'),
                            hintText: tr('public_chat_name_hint'),
                            counterText: '',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'DAMIAN.APK',
                        style: TextStyle(
                          color: _chatPink,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          shadows: <Shadow>[
                            Shadow(color: _chatPink, blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null && _messages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                    child: Column(
                      children: <Widget>[
                        const Icon(Icons.cloud_off_rounded,
                            color: Colors.orangeAccent, size: 30),
                        const SizedBox(height: 7),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _chatMuted, fontSize: 11),
                        ),
                        TextButton.icon(
                          onPressed: () => _refreshMessages(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(tr('public_chat_retry')),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loading && _messages.isEmpty
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: _chatCyan),
                        )
                      : _messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.forum_rounded,
                                        color: _chatCyan, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      tr('public_chat_empty'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: _chatCyan,
                              onRefresh: _refreshMessages,
                              child: ListView.builder(
                                reverse: true,
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 14),
                                itemCount: newestFirst.length,
                                itemBuilder: (context, index) {
                                  final item = newestFirst[index];
                                  final translated = _translatedTexts[item.id];
                                  final myName =
                                      _nameController.text.trim().toLowerCase();
                                  return _ChatMessageBubble(
                                    message: item,
                                    time: _timeLabel(item.createdAt),
                                    displayText: translated ?? item.text,
                                    translated: translated != null,
                                    isMine: myName.isNotEmpty &&
                                        myName ==
                                            item.name.trim().toLowerCase(),
                                  );
                                },
                              ),
                            ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                  decoration: BoxDecoration(
                    color: _chatPanel.withAlpha(245),
                    border: Border(top: BorderSide(color: _chatCyan.withAlpha(130))),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: _chatCyan.withAlpha(18), blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocus,
                              minLines: 1,
                              maxLines: 3,
                              maxLength: PublicChatService.maxMessageLength,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: tr('public_chat_message_hint'),
                                counterText: '',
                                filled: true,
                                fillColor: _chatBg,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: _chatCyan, width: 0.8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: _chatPink, width: 1.3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _sending ? null : _sendMessage,
                              style: FilledButton.styleFrom(
                                backgroundColor: _chatCyan,
                                foregroundColor: _chatBg,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 13),
                                shadowColor: _chatCyan,
                                elevation: 5,
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _chatBg),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('public_chat_rules'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _chatMuted, fontSize: 9, height: 1.35),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        appText(
                          'Traducción automática usa un servicio externo; el chat es público.',
                          'Automatic translation uses an external service; this chat is public.',
                          'A tradução automática usa um serviço externo; este chat é público.',
                          'La traduction automatique utilise un service externe ; ce chat est public.',
                        ),
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: _chatMuted, fontSize: 8),
                      ),
                    ],
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

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.time,
    required this.displayText,
    required this.translated,
    required this.isMine,
  });

  final PublicChatMessage message;
  final String time;
  final String displayText;
  final bool translated;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final accent = isMine ? _chatCyan : _chatPink;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withAlpha(34),
            _chatPanel.withAlpha(238),
            const Color(0xDD080C20),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withAlpha(210), width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withAlpha(34),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.account_circle_rounded, color: accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    shadows: <Shadow>[
                      Shadow(color: accent.withAlpha(110), blurRadius: 7),
                    ],
                  ),
                ),
              ),
              if (translated)
                const Padding(
                  padding: EdgeInsets.only(right: 7),
                  child: Icon(Icons.translate_rounded,
                      color: _chatGreen, size: 13),
                ),
              Text(time,
                  style: const TextStyle(color: _chatMuted, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 7),
          SelectableText(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
              shadows: <Shadow>[
                Shadow(color: Color(0x6600E5FF), blurRadius: 3),
              ],
            ),
          ),
          if (translated && displayText != message.text) ...<Widget>[
            const SizedBox(height: 7),
            Container(height: 1, color: accent.withAlpha(65)),
            const SizedBox(height: 5),
            Text(
              'ORIGINAL · ' + message.text,
              style: const TextStyle(
                color: _chatMuted,
                fontSize: 9,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              appText(
                'TRADUCIDO A TU IDIOMA',
                'TRANSLATED TO YOUR LANGUAGE',
                'TRADUZIDO PARA SEU IDIOMA',
                'TRADUIT DANS VOTRE LANGUE',
              ),
              style: const TextStyle(
                color: _chatGreen,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
