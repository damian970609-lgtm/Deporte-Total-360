import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_i18n.dart';
import 'sports_api_service.dart';

const Color _chatBg = Color(0xFF030814);
const Color _chatPanel = Color(0xFF071326);
const Color _chatLine = Color(0xFF123D65);
const Color _chatCyan = Color(0xFF00E5FF);
const Color _chatGreen = Color(0xFF39FF9C);
const Color _chatMuted = Color(0xFFA9BDD6);

class PublicChatMessage {
  const PublicChatMessage({
    required this.id,
    required this.name,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String text;
  final DateTime createdAt;

  factory PublicChatMessage.fromJson(Map<String, dynamic> json) {
    return PublicChatMessage(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Invitado').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
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

  Exception _responseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return Exception(decoded['error'].toString());
      }
    } catch (_) {
      // Se usa el mensaje de estado HTTP si no hay JSON.
    }
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
      const Duration(seconds: 4),
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
        _loading = false;
        _error = null;
      });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tr('public_chat'),
              style: const TextStyle(
                color: _chatCyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
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
                        labelText: tr('public_chat_name'),
                        hintText: tr('public_chat_name_hint'),
                        counterText: '',
                        isDense: true,
                        border: InputBorder.none,
                      ),
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
              child: _loading && _messages.isEmpty
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
                          decoration: InputDecoration(
                            hintText: tr('public_chat_message_hint'),
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
                          onPressed: _sending ? null : _sendMessage,
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
                    tr('public_chat_rules'),
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
  });

  final PublicChatMessage message;
  final String time;

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
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            message.text,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}
