import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diary/diary_page.dart';
import 'chat/chat_page.dart';
import 'auth/dev_auth.dart';
import 'auth/auth_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DearDiaryApp());
}

class DearDiaryApp extends StatefulWidget {
  const DearDiaryApp({super.key});
  @override
  State<DearDiaryApp> createState() => _DearDiaryAppState();
}

class _DearDiaryAppState extends State<DearDiaryApp>
    with WidgetsBindingObserver {
  final navigatorKey = GlobalKey<NavigatorState>();
  String screen = 'lock';
  String pin = '';
  String error = '';
  String normalPin = '000000';
  String chatPin = '111111';
  bool pinsReady = false;
  StreamSubscription<dynamic>? authSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    unawaited(_initializeAuth());
  }

  Future<void> _initializeAuth() async {
    await DevAuth.initialize();
    if (!mounted) return;
    authSubscription = DevAuth.client?.auth.onAuthStateChange.listen((_) {
      if (mounted && !DevAuth.signedIn && screen == 'chat') {
        setState(() {
          screen = 'diary';
          pin = '';
        });
      }
    });
    setState(() {});
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      normalPin = p.getString('demo_normal_pin') ?? '000000';
      chatPin = p.getString('demo_chat_pin') ?? '111111';
      pinsReady = true;
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      if (mounted) {
        setState(() {
          screen = 'lock';
          pin = '';
          error = '';
        });
      }
    }
  }

  void digit(String value) {
    if (!pinsReady || pin.length >= 6) return;
    setState(() {
      pin += value;
      error = '';
    });
    if (pin.length == 6) {
      final entered = pin;
      setState(() {
        pin = '';
        if (entered == normalPin) {
          screen = 'diary';
        } else if (entered == chatPin) {
          screen = DevAuth.signedIn ? 'chat' : 'auth';
        } else {
          error = 'Please try again';
        }
      });
    }
  }

  Future<void> settings() async {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;
    final current = TextEditingController();
    final replacement = TextEditingController();
    bool privateSlot = false;
    await showDialog<void>(
      context: navContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('PIN settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conversation PIN'),
                value: privateSlot,
                onChanged: (v) => update(() => privateSlot = v),
              ),
              TextField(
                controller: current,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
              TextField(
                controller: replacement,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'New six-digit PIN',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (privateSlot && DevAuth.signedIn)
              TextButton(
                onPressed: () async {
                  if (current.text != chatPin) {
                    ScaffoldMessenger.of(
                      navigatorKey.currentContext!,
                    ).showSnackBar(
                      const SnackBar(content: Text('Check the current PIN.')),
                    );
                    return;
                  }
                  try {
                    await DevAuth.signOut();
                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    setState(() {
                      screen = 'diary';
                      pin = '';
                    });
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(navigatorKey.currentContext!)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to sign out. Please try again.',
                              ),
                            ),
                          );
                    }
                  }
                },
                child: const Text('Sign out'),
              ),
            if (privateSlot)
              TextButton(
                onPressed: () {
                  if (current.text != chatPin) {
                    ScaffoldMessenger.of(
                      navigatorKey.currentContext!,
                    ).showSnackBar(
                      const SnackBar(content: Text('Check the current PIN.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext);
                  setState(() => screen = DevAuth.signedIn ? 'chat' : 'auth');
                },
                child: const Text('Open'),
              ),
            FilledButton(
              onPressed: () async {
                final old = privateSlot ? chatPin : normalPin;
                final other = privateSlot ? normalPin : chatPin;
                final next = replacement.text;
                if (current.text != old ||
                    !RegExp(r'^\d{6}$').hasMatch(next) ||
                    next == other) {
                  ScaffoldMessenger.of(navigatorKey.currentContext!)
                      .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Check the current PIN and choose a different six-digit PIN.',
                          ),
                        ),
                      );
                  return;
                }
                final p = await SharedPreferences.getInstance();
                await p.setString(
                  privateSlot ? 'demo_chat_pin' : 'demo_normal_pin',
                  next,
                );
                if (!mounted || !dialogContext.mounted) return;
                setState(() {
                  if (privateSlot) {
                    chatPin = next;
                  } else {
                    normalPin = next;
                  }
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), () {
      current.dispose();
      replacement.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'Dear Diary',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff8a5862),
        surface: const Color(0xfffff9f3),
      ),
      scaffoldBackgroundColor: const Color(0xfffff9f3),
    ),
    home: switch (screen) {
      'diary' => DiaryPage(onSecretSettings: settings),
      'chat' when DevAuth.signedIn => ChatPage(
        storageScope: DevAuth.client!.auth.currentUser!.id,
        onInstantLock: () => setState(() {
          screen = 'diary';
          pin = '';
        }),
      ),
      'auth' => AuthPage(
        onCancel: () => setState(() {
          screen = 'diary';
          pin = '';
        }),
        onSignedIn: () {
          if (screen == 'auth' && DevAuth.signedIn) {
            setState(() => screen = 'chat');
          }
        },
      ),
      _ => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_stories_outlined,
                        size: 48,
                        color: Color(0xff8a5862),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Dear Diary',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A little space for your thoughts',
                        style: TextStyle(color: Colors.brown.shade400),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Enter your PIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          6,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 7),
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < pin.length
                                  ? const Color(0xff8a5862)
                                  : const Color(0xffe9d9d5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 22,
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final row in [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                        ['', '0', '⌫'],
                      ])
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row
                              .map(
                                (d) => SizedBox(
                                  width: 75,
                                  height: 65,
                                  child: d.isEmpty
                                      ? const SizedBox()
                                      : TextButton(
                                          onPressed: () {
                                            if (d == '⌫') {
                                              if (pin.isNotEmpty) {
                                                setState(
                                                  () => pin = pin.substring(
                                                    0,
                                                    pin.length - 1,
                                                  ),
                                                );
                                              }
                                            } else {
                                              digit(d);
                                            }
                                          },
                                          child: Text(
                                            d,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              color: Color(0xff4d3838),
                                            ),
                                          ),
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'DEMO ONLY · DATA IS NOT ENCRYPTED',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: Color(0xffb69993),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    },
  );
}
