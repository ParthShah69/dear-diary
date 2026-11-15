import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/dev_auth.dart';
import 'supabase_chat_service.dart';

class CloudChatPage extends StatefulWidget {
  final VoidCallback onInstantLock;
  const CloudChatPage({super.key, required this.onInstantLock});

  @override
  State<CloudChatPage> createState() => _CloudChatPageState();
}

class _CloudChatPageState extends State<CloudChatPage> {
  late final SupabaseChatService _service;
  RealtimeChannel? _channel;
  List<ChatPair> _chats = [];
  List<Map<String, dynamic>> _requests = [];
  String? _username;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = SupabaseChatService(DevAuth.client!);
    _load();
    _channel = _service.client
        .channel('cloud-chat-home-${_service.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_members',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.username(),
        _service.requests(),
        _service.conversations(),
      ]);
      if (!mounted) return;
      setState(() {
        _username = results[0] as String?;
        _requests = results[1] as List<Map<String, dynamic>>;
        _chats = results[2] as List<ChatPair>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your online chats. Check the database setup and connection.';
        });
      }
    }
  }

  Future<void> _setUsername() async {
    final controller = TextEditingController(text: _username ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose your username'),
        content: TextField(
          controller: controller,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: '3–24 letters, digits or _',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    try {
      await _service.ensureUsername(value);
      await _load();
    } catch (_) {
      _message('That username is invalid or already in use.');
    }
  }

  Future<void> _addFriend() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
          controller: controller,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'Their exact username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.sendRequest(value);
      await _load();
      _message('Friend request sent.');
    } catch (_) {
      _message(
        'Could not send that request. Check the username or whether a request already exists.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> request, bool accept) async {
    setState(() => _busy = true);
    try {
      await _service.respond(request['id'] as String, accept);
      await _load();
      _message(accept ? 'Friend request accepted.' : 'Request declined.');
    } catch (_) {
      _message('Could not update that request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _peerFor(Map<String, dynamic> row) =>
      row['requester_id'] == _service.userId
      ? 'Request to @${(row['recipient'] as Map?)?['username'] ?? 'friend'}'
      : 'Request from @${(row['requester'] as Map?)?['username'] ?? 'friend'}';

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) unawaited(_service.client.removeChannel(channel));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffaf7f2),
    appBar: AppBar(
      backgroundColor: const Color(0xfffaf7f2),
      leading: IconButton(
        onPressed: widget.onInstantLock,
        icon: const Icon(Icons.lock_outline_rounded),
        tooltip: 'Instant lock',
      ),
      title: const Text('A little conversation'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _addFriend,
          icon: const Icon(Icons.person_add_alt_1),
          tooltip: 'Add friend',
        ),
        IconButton(
          onPressed: widget.onInstantLock,
          icon: const Icon(Icons.close),
          tooltip: 'Return to diary',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_error != null)
                  _Notice(
                    text: _error!,
                    action: TextButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      _username == null ? 'Set your username' : '@$_username',
                    ),
                    subtitle: const Text(
                      'Your friend can find you by this username.',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _setUsername,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Conversations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                if (_chats.isEmpty)
                  const _Notice(
                    text: 'No connected friends yet. Add a username, then accept the request on the other account.',
                  )
                else
                  ..._chats.map(
                    (chat) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('@${chat.peerUsername}'),
                        subtitle: const Text('Online conversation'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CloudConversationPage(
                              service: _service,
                              chat: chat,
                              onInstantLock: widget.onInstantLock,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Friend requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                ..._requests.where((r) => r['status'] == 'pending').map((
                  request,
                ) {
                  final incoming = request['recipient_id'] == _service.userId;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        incoming
                            ? Icons.mark_email_unread_outlined
                            : Icons.schedule,
                      ),
                      title: Text(_peerFor(request)),
                      subtitle: Text(
                        incoming
                            ? 'Accept to start a conversation.'
                            : 'Waiting for their response.',
                      ),
                      trailing: incoming
                          ? Wrap(
                              children: [
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respond(request, false),
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Decline',
                                ),
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respond(request, true),
                                  icon: const Icon(Icons.check),
                                  tooltip: 'Accept',
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
  );
}

class CloudConversationPage extends StatefulWidget {
  final SupabaseChatService service;
  final ChatPair chat;
  final VoidCallback onInstantLock;
  const CloudConversationPage({
    super.key,
    required this.service,
    required this.chat,
    required this.onInstantLock,
  });

  @override
  State<CloudConversationPage> createState() => _CloudConversationPageState();
}

class _CloudConversationPageState extends State<CloudConversationPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  RealtimeChannel? _channel;
  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, dynamic>> _receipts = {};
  final Set<String> _receiptPending = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;

  void _lock() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onInstantLock();
  }

  @override
  void initState() {
    super.initState();
    _load();
    final client = widget.service.client;
    _channel = client
        .channel('cloud-messages-${widget.chat.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.chat.id,
          ),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_receipts',
          callback: (_) => _loadReceipts(),
        )
        .subscribe();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.service.messages(widget.chat.id);
      final unread = rows
          .where((m) => m['sender_id'] != widget.service.userId)
          .toList();
      for (final message in unread) {
        final messageId = message['id'] as String;
        if (_receiptPending.contains(messageId)) continue;
        _receiptPending.add(messageId);
        try {
          await widget.service.acknowledge(messageId, read: true);
        } catch (_) {
          _receiptPending.remove(messageId);
        }
      }
      final receipts = await widget.service.receipts(
        rows.map((m) => m['id'] as String).toList(),
      );
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _receipts = receipts;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load messages. Check the database Realtime and access setup.';
        });
      }
    }
  }

  Future<void> _loadReceipts() async {
    try {
      final receipts = await widget.service.receipts(
        _messages.map((m) => m['id'] as String).toList(),
      );
      if (mounted) setState(() => _receipts = receipts);
    } catch (_) {}
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.service.sendMessage(widget.chat.id, body);
      _text.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Message not sent. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    final channel = _channel;
    if (channel != null) {
      unawaited(widget.service.client.removeChannel(channel));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffaf7f2),
    appBar: AppBar(
      backgroundColor: const Color(0xfffaf7f2),
      leading: IconButton(
        onPressed: _lock,
        icon: const Icon(Icons.lock_outline),
        tooltip: 'Instant lock',
      ),
      title: Text('@${widget.chat.peerUsername}'),
      actions: [
        IconButton(
          onPressed: _lock,
          icon: const Icon(Icons.close),
          tooltip: 'Instant lock',
        ),
      ],
    ),
    body: Column(
      children: [
        if (_error != null)
          _Notice(
            text: _error!,
            action: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? const Center(child: Text('Say hello to begin.'))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final mine = message['sender_id'] == widget.service.userId;
                    final receipt = _receipts[message['id'] as String];
                    final read = receipt?['read_at'] != null;
                    final time = DateTime.tryParse(
                      message['sent_at'] as String? ?? '',
                    )?.toLocal();
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .78,
                        ),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.fromLTRB(13, 10, 13, 6),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xffe8d8c9) : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: mine ? const Radius.circular(4) : null,
                            bottomLeft: mine ? null : const Radius.circular(4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(message['body'] as String),
                            const SizedBox(height: 4),
                            Text(
                              '${time == null ? '' : TimeOfDay.fromDateTime(time).format(context)}${mine ? (read
                                        ? ' · Seen'
                                        : receipt != null
                                        ? ' · Delivered'
                                        : ' · Sent') : ''}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xff897b72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Notice({required this.text, this.action});
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xfffff0dd),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(text), ?action],
      ),
    ),
  );
}
