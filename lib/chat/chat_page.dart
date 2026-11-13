import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A local-only conversation preview. It does not connect to another person.
class ChatPage extends StatefulWidget {
  final VoidCallback onInstantLock;
  const ChatPage({super.key, required this.onInstantLock});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _Message {
  String text;
  final DateTime time;
  final List<String> previous;
  _Message(this.text, this.time, [List<String>? previous])
    : previous = previous ?? [];
  Map<String, dynamic> toJson() => {
    'text': text,
    'time': time.toIso8601String(),
    'previous': previous,
  };
  factory _Message.fromJson(Map<String, dynamic> json) => _Message(
    json['text'] as String,
    DateTime.parse(json['time'] as String),
    (json['previous'] as List<dynamic>? ?? []).cast<String>(),
  );
}

class _ChatPageState extends State<ChatPage> {
  static const _draftKey = 'demo_chat_draft_v1';
  static const _messagesKey = 'demo_chat_messages_v1';
  final _controller = TextEditingController();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  SharedPreferences? _prefs;
  List<_Message> _messages = [];
  bool _loaded = false;
  bool _corrupt = false;
  bool _sending = false;
  bool _locking = false;
  Object? _draftError;
  Future<void> _draftWrites = Future<void>.value();
  bool _searching = false;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messagesKey);
    var messages = <_Message>[];
    var corrupt = false;
    if (raw != null) {
      try {
        messages = (jsonDecode(raw) as List)
            .map((e) => _Message.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        corrupt = true;
      }
    }
    if (!mounted) return;
    _prefs = prefs;
    _controller.text = prefs.getString(_draftKey) ?? '';
    _controller.addListener(_saveDraft);
    setState(() {
      _messages = messages;
      _corrupt = corrupt;
      _loaded = true;
    });
  }

  void _saveDraft() {
    final value = _controller.text;
    final prefs = _prefs;
    if (prefs == null) return;
    _draftWrites = _draftWrites.then((_) async {
      try {
        if (!await prefs.setString(_draftKey, value)) {
          throw StateError('Unable to save draft');
        }
        _draftError = null;
      } catch (error) {
        _draftError = error;
      }
    });
  }

  Future<void> _lock() async {
    if (_locking || _sending) return;
    setState(() => _locking = true);
    _saveDraft();
    await _draftWrites;
    if (!mounted) return;
    setState(() => _locking = false);
    if (_draftError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the draft. Please try again.'),
        ),
      );
      return;
    }
    widget.onInstantLock();
  }

  Future<void> _saveMessages() async {
    if (_corrupt) throw StateError('Stored messages could not be read');
    final saved = await _prefs?.setString(
      _messagesKey,
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
    if (saved != true) throw StateError('Unable to save messages');
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_loaded || _corrupt || _sending || _locking) return;
    setState(() {
      _sending = true;
      _messages.add(_Message(text, DateTime.now()));
    });
    try {
      await _saveMessages();
      if (!mounted) return;
      _controller.clear();
      await _draftWrites;
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.removeLast());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the message. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _edit(_Message message) async {
    final editor = TextEditingController(text: message.text);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLines: 5,
          minLines: 2,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editor.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (!mounted ||
        updated == null ||
        updated.isEmpty ||
        updated == message.text) {
      return;
    }
    setState(() {
      message.previous.add(message.text);
      message.text = updated;
    });
    await _saveMessages();
  }

  void _history(_Message message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (message.previous.isEmpty)
                const Text('This message has not been edited.'),
              ...message.previous.map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _attachments() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attachments',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Photo, video and voice messages are planned. This preview stores text only on this device.',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachment(Icons.image_outlined, 'Photo'),
                  _attachment(Icons.videocam_outlined, 'Video'),
                  _attachment(Icons.mic_none_rounded, 'Voice'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachment(IconData icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xfff2e6da),
        child: Icon(icon, color: const Color(0xff795747)),
      ),
      const SizedBox(height: 6),
      Text(label),
    ],
  );
  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date ?? DateTime.now(),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  void dispose() {
    _controller.removeListener(_saveDraft);
    _saveDraft();
    _controller.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff302c2a);
    const muted = Color(0xff897b72);
    final filtered = _messages.where((m) {
      final matchesText = m.text.toLowerCase().contains(
        _search.text.toLowerCase(),
      );
      final matchesDate =
          _date == null ||
          (m.time.year == _date!.year &&
              m.time.month == _date!.month &&
              m.time.day == _date!.day);
      return matchesText && matchesDate;
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xfffaf7f2),
      appBar: AppBar(
        backgroundColor: const Color(0xfffaf7f2),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: _lock,
          tooltip: 'Return to diary',
        ),
        titleSpacing: 0,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages',
                  border: InputBorder.none,
                ),
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A little conversation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'LOCAL PREVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: muted,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _date = null;
              }
            }),
            icon: Icon(_searching ? Icons.close : Icons.search_rounded),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: _lock,
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Instant lock',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xfffff0dd),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Local preview · messages stay on this device. No live connection yet.',
                style: TextStyle(color: Color(0xff785536), fontSize: 12),
              ),
            ),
            if (_corrupt)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Saved messages could not be read. They have been preserved and sending is disabled.',
                  style: TextStyle(color: Color(0xff9b312a)),
                ),
              ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        _date == null
                            ? 'Choose date'
                            : '${_date!.day}/${_date!.month}/${_date!.year}',
                      ),
                    ),
                    if (_date != null)
                      TextButton(
                        onPressed: () => setState(() => _date = null),
                        child: const Text('Clear date'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              size: 42,
                              color: Color(0xffc3ad9c),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _messages.isEmpty
                                  ? 'A quiet space to begin'
                                  : 'No matching messages',
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontSize: 22,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _messages.isEmpty
                                  ? 'Write a message to try the local preview.'
                                  : 'Try a different word or date.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final message = filtered[index];
                        final time = TimeOfDay.fromDateTime(message.time)
                            .format(context);
                        return Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onLongPress: () => showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              builder: (sheetContext) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit_outlined),
                                      title: const Text('Edit message'),
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _edit(message);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.history),
                                      title: const Text('View edit history'),
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _history(message);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .78,
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
                              decoration: BoxDecoration(
                                color: const Color(0xffe8d8c9),
                                borderRadius: BorderRadius.circular(17)
                                    .copyWith(
                                      bottomRight: const Radius.circular(4),
                                    ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    message.text,
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${message.previous.isNotEmpty ? 'edited · ' : ''}$time',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xffeee7e0))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _attachments,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: const Color(0xff8b6f60),
                    tooltip: 'Attachments',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _loaded && !_sending && !_locking && !_corrupt,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        filled: true,
                        fillColor: const Color(0xfff7f3ef),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xff765c4e),
                    child: IconButton(
                      onPressed: _sending || _locking || _corrupt
                          ? null
                          : _send,
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Save message',
                    ),
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
