import 'package:material_ui/material_ui.dart';

import 'dev_auth.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onSignedIn;
  final VoidCallback onCancel;
  const AuthPage({super.key, required this.onSignedIn, required this.onCancel});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  bool creating = false;
  bool busy = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if ((!DevAuth.usernameOnly && DevAuth.normalizeEmail(email.text) == null) ||
        ((creating || DevAuth.usernameOnly) &&
            DevAuth.normalize(username.text) == null) ||
        password.text.length < 8) {
      setState(
        () => message = DevAuth.usernameOnly
            ? 'Use a username of 3–24 letters, digits or underscores and a password of at least 8 characters.'
            : creating
            ? 'Enter a valid email, a username of 3–24 letters, digits or underscores, and a password of at least 8 characters.'
            : 'Enter a valid email address and a password of at least 8 characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (creating) {
        final hasSession = await DevAuth.signUp(
          username.text,
          password.text,
          email: email.text,
        );
        if (!mounted) return;
        if (!hasSession) {
          setState(() => message = DevAuth.signupConfirmationHelp);
          return;
        }
      } else {
        await DevAuth.signIn(
          DevAuth.usernameOnly ? username.text : email.text,
          password.text,
        );
      }
      if (mounted && DevAuth.signedIn) widget.onSignedIn();
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              message = DevAuth.safeFailureMessage(error, signingUp: creating),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: widget.onCancel,
        icon: const Icon(Icons.arrow_back),
      ),
      title: Text(creating ? 'Create account' : 'Sign in'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    creating ? 'Create your account' : 'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DevAuth.usernameOnly
                        ? creating
                              ? 'Create your account with a username and password.'
                              : 'Sign in with your username and password.'
                        : creating
                        ? 'Use an email address you can access. Friends find you by your username.'
                        : 'Sign in with the email address used when you created your account. Your username is used to find you in chat.',
                  ),
                  const SizedBox(height: 24),
                  if (DevAuth.usernameOnly) ...[
                    TextField(
                      controller: username,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextField(
                      controller: email,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (creating && !DevAuth.usernameOnly) ...[
                    TextField(
                      controller: username,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!DevAuth.initialized)
                    const Text('Preparing account sign-in…')
                  else if (DevAuth.client == null)
                    Text(
                      DevAuth.initializationError ??
                          'Account service unavailable.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        message!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton(
                    onPressed: busy || DevAuth.client == null ? null : submit,
                    child: busy
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Connecting…'),
                            ],
                          )
                        : Text(creating ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            creating = !creating;
                            message = null;
                          }),
                    child: Text(
                      creating
                          ? 'Already have an account? Sign in'
                          : 'Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
