import 'app_section_design.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_i18n.dart';
import 'sports_api_service.dart';
import 'channel_catalog_service.dart';

const Color _chatBg = Color(0xFF000000);
const Color _chatPanel = Color(0xFF07090D);
const Color _chatLine = Color(0xFF0047FF);
const Color _chatCyan = Color(0xFF00A3FF);
const Color _chatGreen = Color(0xFF39FF14);
const Color _chatMuted = Color(0xFFEAF0F8);

class PublicChatMessage {
  const PublicChatMessage({
    required this.id,
    required this.name,
    required this.text,
    required this.createdAt,
    this.isMine = false,
    this.deleted = false,
  });

  final String id;
  final String name;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final bool deleted;

  factory PublicChatMessage.fromJson(Map<String, dynamic> json) {
    return PublicChatMessage(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Invitado').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      isMine: json['isMine'] == true,
      deleted: json['deleted'] == true,
    );
  }
}

class PublicChatException implements Exception {
  const PublicChatException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class PublicChatService {
  PublicChatService({
    http.Client? client,
    Future<Map<String, String>> Function()? authHeadersProvider,
  })  : _client = client ?? http.Client(),
        _authHeadersProvider =
            authHeadersProvider ?? channelCatalogService.chatAuthorizationHeaders;

  static const int maxNameLength = 24;
  static const int maxMessageLength = 500;
  static const Duration timeout = Duration(seconds: 12);

  final http.Client _client;
  final Future<Map<String, String>> Function() _authHeadersProvider;
  bool canModerate = false;

  Uri _messagesUri([String? messageId]) {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw Exception(appText(
        'El servidor del chat no está configurado.',
        'The chat server is not configured.',
        'O servidor do chat não está configurado.',
        'Le serveur de discussion n’est pas configuré.',
      ));
    }
    final suffix = messageId == null
        ? ''
        : '/' + Uri.encodeComponent(messageId);
    return Uri.parse(base + '/api/chat/messages' + suffix);
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    return <String, String>{
      'Accept': 'application/json',
      ...(await _authHeadersProvider()),
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  Future<List<PublicChatMessage>> loadMessages() async {
    final response = await _client
        .get(_messagesUri(), headers: await _headers())
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['messages'] is! List) {
      throw Exception(appText(
        'El servidor devolvió una respuesta de chat inválida.',
        'The server returned an invalid chat response.',
        'O servidor retornou uma resposta de chat inválida.',
        'Le serveur a renvoyé une réponse de discussion invalide.',
      ));
    }
    canModerate = decoded['canModerate'] == true;
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
  }) async {
    final response = await _client
        .post(
          _messagesUri(),
          headers: await _headers(jsonBody: true),
          body: jsonEncode(<String, String>{
            'name': name.trim(),
            'text': text.trim(),
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 201) {
      throw _responseError(response);
    }
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

  Future<void> deleteMessage(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
      throw Exception('El identificador del mensaje no es válido.');
    }
    final response = await _client
        .delete(
          _messagesUri(id),
          headers: await _headers(),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw _responseError(response);
    }
  }

  PublicChatException _responseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        final error = decoded['error'];
        final message = error is Map
            ? (error['message'] ?? error['code'] ?? 'Error del servidor')
                .toString()
            : error.toString();
        return PublicChatException(response.statusCode, message);
      }
    } catch (_) {
      // Se usa el mensaje de estado HTTP si no hay JSON.
    }
    if (response.statusCode == 401) {
      return PublicChatException(response.statusCode, appText(
        'Tu sesión Google caducó. Vuelve a iniciar sesión en la aplicación.',
        'Your Google session expired. Sign in again in the app.',
        'Sua sessão Google expirou. Entre novamente no aplicativo.',
        'Votre session Google a expiré. Reconnectez-vous dans l’application.',
      ));
    }
    if (response.statusCode == 403) {
      return PublicChatException(response.statusCode, appText(
        'El Chat está reservado para compradores con licencia de pago activa.',
        'Chat is reserved for buyers with an active paid license.',
        'O Chat é exclusivo para compradores com licença paga ativa.',
        'Le Chat est réservé aux acheteurs avec une licence payante active.',
      ));
    }
    if (response.statusCode == 429) {
      return PublicChatException(response.statusCode, appText(
        'Espera un momento antes de volver a enviar.',
        'Please wait before sending another message.',
        'Aguarde um momento antes de enviar novamente.',
        'Veuillez patienter avant de renvoyer un message.',
      ));
    }
    return PublicChatException(response.statusCode, 'HTTP ' + response.statusCode.toString());
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();

  Timer? _pollTimer;
  List<PublicChatMessage> _messages = <PublicChatMessage>[];
  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;
  bool _canModerate = false;
  bool _accessDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
    if (widget.isActive) {
      _refreshMessages();
      _startPolling();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant PublicChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _refreshMessages();
      _startPolling();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshMessages(silent: true),
    );
  }

  Future<void> _loadSavedName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('public_chat_nickname') ?? '';
      if (mounted && _nameController.text.isEmpty) {
        setState(() => _nameController.text = saved);
      }
    } catch (_) {
      // El chat sigue disponible si el usuario introduce un alias manualmente.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _nameController.dispose();
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshMessages({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final messages = await _service.loadMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _canModerate = _service.canModerate;
        _accessDenied = false;
        _loading = false;
        _error = null;
      });
      if (widget.isActive && _pollTimer == null) _startPolling();
    } catch (error) {
      if (!mounted) return;
      final denied = error is PublicChatException && error.statusCode == 403;
      setState(() {
        _loading = false;
        if (denied) {
          _accessDenied = true;
          _canModerate = false;
          _messages = <PublicChatMessage>[];
        }
        if (denied || !silent || _messages.isEmpty) _error = error.toString();
      });
      if (denied) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
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
      final sent = await _service.sendMessage(name: name, text: message);
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

  Future<void> _deleteMessage(PublicChatMessage item) async {
    if (!_canModerate || item.deleted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _chatPanel,
        title: Text(appText(
          'Eliminar mensaje',
          'Delete message',
          'Excluir mensagem',
          'Supprimer le message',
        )),
        content: Text(appText(
          'El mensaje se ocultará para todos los compradores.',
          'The message will be hidden from all buyers.',
          'A mensagem será ocultada para todos os compradores.',
          'Le message sera masqué pour tous les acheteurs.',
        )),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText('Cancelar', 'Cancel', 'Cancelar', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(appText('Eliminar', 'Delete', 'Excluir', 'Supprimer')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteMessage(item.id);
      await _refreshMessages();
    } catch (error) {
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
        backgroundColor: _chatBg,
        title: AppSectionTitle(
          icon: Icons.forum_rounded,
          title: appText(
            'CHAT DE COMPRADORES',
            'BUYERS CHAT',
            'CHAT DE COMPRADORES',
            'CHAT DES ACHETEURS',
          ).toUpperCase(),
          accent: _chatCyan,
          subtitle: appText(
            'COMUNIDAD PRIVADA · LICENCIA ACTIVA',
            'PRIVATE COMMUNITY · ACTIVE LICENSE',
            'COMUNIDADE PRIVADA · LICENÇA ATIVA',
            'COMMUNAUTÉ PRIVÉE · LICENCE ACTIVE',
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: appText('Actualizar mensajes', 'Refresh messages',
                'Atualizar mensagens', 'Actualiser les messages'),
            onPressed: () => _refreshMessages(),
            icon: const Icon(Icons.refresh_rounded, color: _chatCyan),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _chatCyan.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _chatCyan.withAlpha(100)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.verified_user_rounded, color: _chatGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appText(
                        'Acceso privado para compradores con licencia de pago activa. Tu cuenta Google verifica tu membresía.',
                        'Private access for buyers with an active paid license. Your Google account verifies membership.',
                        'Acesso privado para compradores com licença paga ativa. Sua conta Google confirma a assinatura.',
                        'Accès privé aux acheteurs avec une licence payante active. Votre compte Google vérifie votre adhésion.',
                      ),
                      style: const TextStyle(color: _chatMuted, fontSize: 10, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _chatPanel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _chatLine),
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
                      decoration: InputDecoration(
                        labelText: appText(
                          'Alias de comprador',
                          'Buyer nickname',
                          'Apelido do comprador',
                          'Pseudo acheteur',
                        ),
                        hintText: appText(
                          'Alias público (se fija con tu primer mensaje)',
                          'Public nickname (locked with your first message)',
                          'Apelido público (fixado na primeira mensagem)',
                          'Pseudo public (fixé avec votre premier message)',
                        ),
                        counterText: '',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      enabled: !_accessDenied,
                    ),
                  ),
                ],
              ),
            ),
            if (_accessDenied)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _error ?? appText(
                    'Este Chat requiere una licencia de pago activa.',
                    'This Chat requires an active paid license.',
                    'Este Chat exige uma licença paga ativa.',
                    'Ce Chat nécessite une licence payante active.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (_error != null && _messages.isEmpty && !_accessDenied)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                child: Column(
                  children: <Widget>[
                    const Icon(Icons.cloud_off_rounded,
                        color: Colors.orangeAccent, size: 30),
                    const SizedBox(height: 7),
                    Text(_error!, textAlign: TextAlign.center,
                        style: const TextStyle(color: _chatMuted, fontSize: 11)),
                    TextButton.icon(
                      onPressed: () => _refreshMessages(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr('public_chat_retry')),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _accessDenied
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.orangeAccent,
                              size: 46,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appText(
                                'El Chat es exclusivo para compradores con licencia de pago activa.',
                                'Chat is exclusive to buyers with an active paid license.',
                                'O Chat é exclusivo para compradores com licença paga ativa.',
                                'Le Chat est réservé aux acheteurs avec une licence payante active.',
                              ),
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
                  : _loading && _messages.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: _chatCyan),
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
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                                itemCount: newestFirst.length,
                                itemBuilder: (context, index) {
                                  final item = newestFirst[index];
                                  return _ChatMessageBubble(
                                    message: item,
                                    time: _timeLabel(item.createdAt),
                                    onDelete: _canModerate && !item.deleted
                                        ? () => _deleteMessage(item)
                                        : null,
                                  );
                                },
                              ),
                            ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
              decoration: const BoxDecoration(
                color: _chatPanel,
                border: Border(top: BorderSide(color: _chatLine)),
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
                          enabled: !_accessDenied,
                          decoration: InputDecoration(
                            hintText: appText(
                              'Escribe a la comunidad de compradores…',
                              'Write to the buyers community…',
                              'Escreva para a comunidade de compradores…',
                              'Écrivez à la communauté des acheteurs…',
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: _chatBg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _chatLine),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _sending || _accessDenied ? null : _sendMessage,
                          style: FilledButton.styleFrom(
                            backgroundColor: _chatCyan,
                            foregroundColor: _chatBg,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
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
                    appText(
                      'Comunidad privada: no compartas contraseñas, datos bancarios ni enlaces sospechosos.',
                      'Private community: do not share passwords, banking details or suspicious links.',
                      'Comunidade privada: não compartilhe senhas, dados bancários ou links suspeitos.',
                      'Communauté privée : ne partagez pas de mots de passe, données bancaires ou liens suspects.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _chatMuted, fontSize: 9, height: 1.35),
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

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.time,
    this.onDelete,
  });

  final PublicChatMessage message;
  final String time;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: _chatPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _chatLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.account_circle_rounded,
                  color: _chatCyan, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _chatCyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(time,
                  style: const TextStyle(color: _chatMuted, fontSize: 9)),
              if (onDelete != null)
                IconButton(
                  tooltip: appText(
                    'Eliminar mensaje',
                    'Delete message',
                    'Excluir mensagem',
                    'Supprimer le message',
                  ),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            message.text,
            style: TextStyle(
              color: message.deleted ? _chatMuted : Colors.white,
              fontSize: 13,
              height: 1.35,
              fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
