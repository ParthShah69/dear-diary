import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A local-only diary prototype. Its preferences storage is not encrypted.
class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key, this.onSecretSettings});

  final VoidCallback? onSecretSettings;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _Note {
  _Note({required this.id, required this.text, required this.updatedAt});

  final String id;
  String text;
  DateTime updatedAt;

  factory _Note.fromJson(Map<String, dynamic> json) => _Note(
    id: json['id'] as String,
    text: json['text'] as String? ?? '',
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class _DiaryPageState extends State<DiaryPage> with WidgetsBindingObserver {
  static const _storageKey = 'dear_diary_notes_v1';
  final _editor = TextEditingController();
  final _focus = FocusNode();
  final List<_Note> _notes = [];
  SharedPreferences? _prefs;
  Future<void> _writeQueue = Future.value();
  _Note? _selected;
  bool _loading = true;
  bool _switching = false;
  int _titleTaps = 0;
  DateTime? _firstTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editor.addListener(_onEdit);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final loaded = <_Note>[];
    if (raw != null) {
      try {
        loaded.addAll(
          (jsonDecode(raw) as List).map(
            (item) => _Note.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      } catch (_) {
        // Keep the existing value untouched if it cannot be decoded.
      }
    }
    if (!mounted) return;
    _prefs = prefs;
    loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _notes.addAll(loaded);
    if (_notes.isEmpty && raw == null) {
      _notes.add(
        _Note(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: 'Dear Diary,\n\nA cup of chai and a little time to pause. May today bring small moments of joy and kindness.',
          updatedAt: DateTime.now(),
        ),
      );
    }
    if (_notes.isNotEmpty) _select(_notes.first);
    setState(() => _loading = false);
  }

  void _select(_Note note) {
    _switching = true;
    _selected = note;
    _editor.value = TextEditingValue(
      text: note.text,
      selection: TextSelection.collapsed(offset: note.text.length),
    );
    _switching = false;
  }

  void _onEdit() {
    if (_switching || _selected == null) return;
    _selected!
      ..text = _editor.text
      ..updatedAt = DateTime.now();
    _persist();
    if (mounted) setState(() {});
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    final snapshot = jsonEncode(_notes.map((note) => note.toJson()).toList());
    _writeQueue = _writeQueue.then((_) async {
      await prefs.setString(_storageKey, snapshot);
    });
  }

  void _newNote() {
    final note = _Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: '',
      updatedAt: DateTime.now(),
    );
    setState(() {
      _notes.insert(0, note);
      _select(note);
    });
    _persist();
    _focus.requestFocus();
  }

  void _tapTitle() {
    final now = DateTime.now();
    if (_firstTap == null ||
        now.difference(_firstTap!) > const Duration(seconds: 3)) {
      _firstTap = now;
      _titleTaps = 0;
    }
    _titleTaps++;
    if (_titleTaps == 6) {
      _titleTaps = 0;
      _firstTap = null;
      _focus.unfocus();
      _persist();
      widget.onSecretSettings?.call();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _persist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persist();
    _editor.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _date(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff352d2b);
    return Scaffold(
      backgroundColor: const Color(0xfff8f5f1),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _tapTitle,
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR LITTLE SPACE',
                                  style: TextStyle(
                                    color: Color(0xffa47c70),
                                    fontSize: 10,
                                    letterSpacing: 2.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Dear Diary',
                                  style: TextStyle(
                                    color: ink,
                                    fontFamily: 'serif',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _newNote,
                          tooltip: 'New entry',
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _selected == null
                        ? Center(
                            child: TextButton(
                              onPressed: _newNote,
                              child: const Text('Create an entry'),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0b3f302a),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 16,
                                          color: Color(0xffb08e7e),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _date(_selected!.updatedAt)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xff9a8177),
                                            fontSize: 11,
                                            letterSpacing: 1.3,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    const Text(
                                      'A moment for yourself.',
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 24,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _editor,
                                      focusNode: _focus,
                                      minLines: 9,
                                      maxLines: null,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: const TextStyle(
                                        color: ink,
                                        fontSize: 16,
                                        height: 1.6,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Dear diary,\n\nWhat is on your mind today?',
                                        hintStyle: TextStyle(
                                          color: Color(0xffb9aaa3),
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                    const Divider(color: Color(0xfff0e8e3)),
                                    const SizedBox(height: 8),
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.cloud_done_outlined,
                                          size: 16,
                                          color: Color(0xffa58b7e),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Saved on this device',
                                          style: TextStyle(
                                            color: Color(0xffa58b7e),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              const Text(
                                'Your entries',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 22,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...([..._notes]..sort(
                                    (a, b) =>
                                        b.updatedAt.compareTo(a.updatedAt),
                                  ))
                                  .map(
                                    (note) => ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xffeee4dd),
                                        child: Icon(
                                          Icons.menu_book_outlined,
                                          color: Color(0xff997b6f),
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        note.text.trim().isEmpty
                                            ? 'A new page'
                                            : note.text
                                                  .trim()
                                                  .split('\n')
                                                  .first,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _date(note.updatedAt),
                                        style: const TextStyle(
                                          color: Color(0xff9e8f87),
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: note.id == _selected?.id
                                          ? const Icon(
                                              Icons.check_circle,
                                              size: 17,
                                              color: Color(0xffb48779),
                                            )
                                          : null,
                                      onTap: () =>
                                          setState(() => _select(note)),
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

