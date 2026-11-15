import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Email/password authentication with a separate public username for chat.
class DevAuth {
  static const requestTimeout = Duration(seconds: 25);
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Enable only in a disposable Supabase project with email confirmation off.
  static const usernameOnly = bool.fromEnvironment(
    'USERNAME_ONLY_AUTH',
    defaultValue: false,
  );
  static SupabaseClient? client;
  static String? initializationError;
  static bool initialized = false;
  static Future<void>? _initialization;

  static String get signupConfirmationHelp => usernameOnly
      ? 'Account created. You can now sign in with your username and password.'
      : 'Account created. Check your email and confirm it before signing in. If no message arrives, check spam or configure email delivery.';

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    if (url.isEmpty || key.isEmpty) {
      initializationError = 'Server configuration is missing.';
      initialized = true;
      return;
    }
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } catch (error) {
      initializationError = _configurationFailure(error)
          ? 'Account service configuration looks invalid. Check the app connection settings.'
          : 'Unable to initialize the account service. Check the project configuration and internet connection.';
    } finally {
      initialized = true;
    }
  }

  static String? normalize(String value) {
    final username = value.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username) ? username : null;
  }

  static String? normalizeEmail(String value) {
    final email = value.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return null;
    }
    return email;
  }

  /// Supabase Auth's password API is email-based. In the disposable test mode,
  /// map the handle to a valid-looking internal identity at this project's host.
  /// No messages can be delivered there; email confirmation must be off.
  static String internalEmailForUsername(
    String username, {
    String? projectUrl,
  }) {
    final name = normalize(username);
    final host = Uri.tryParse(projectUrl ?? url)?.host;
    if (name == null || host == null || host.isEmpty) {
      throw StateError(
        'Username-only auth needs a valid Supabase project URL.',
      );
    }
    return '$name@$host';
  }

  static bool get signedIn => client?.auth.currentSession != null;

  /// Converts provider failures into safe, actionable copy. Never expose the
  /// raw AuthException to the UI: provider responses can include email details.
  static String safeFailureMessage(Object error, {required bool signingUp}) {
    if (error is TimeoutException) {
      return signingUp
          ? 'This is taking longer than expected. Check your connection, then try signing in before creating the account again.'
          : 'This is taking longer than expected. Check your connection and try signing in again.';
    }
    if (error is AuthException) {
      final code = error.code?.toLowerCase() ?? '';
      final detail = error.message.toLowerCase();

      if (_configurationFailure(error)) {
        return 'Account service configuration looks invalid. Check the app connection settings.';
      }
      if (code == 'email_provider_disabled' ||
          code == 'signup_disabled' ||
          detail.contains('signups not allowed') ||
          detail.contains('signups are disabled')) {
        return signingUp
            ? 'Account creation is currently unavailable. Check the account service settings.'
            : 'Sign-in is currently unavailable. Check the account service settings.';
      }
      if (code == 'email_address_invalid' ||
          (code == 'validation_failed' &&
              detail.contains('email') &&
              (detail.contains('invalid') || detail.contains('valid')))) {
        return usernameOnly
            ? 'This username could not be used. Check the account service settings or choose another username.'
            : 'Enter a valid email address and try again.';
      }
      if (signingUp && code == 'email_address_not_authorized') {
        return 'A confirmation message could not be sent. Check the email address or try again later.';
      }
      if (signingUp && code == 'weak_password') {
        return 'Choose a stronger password, then try again.';
      }
      if (signingUp && code == 'over_email_send_rate_limit') {
        return 'Too many confirmation messages were requested. Wait before trying again.';
      }
      if (code == 'over_request_rate_limit') {
        return 'Too many attempts were made from this network. Wait a few minutes, then try again.';
      }
      if (signingUp &&
          (code == 'unexpected_failure' ||
              detail.contains('database error saving new user'))) {
        return 'This account could not be created. The username may already be taken; try signing in or choose another username.';
      }
      if (signingUp &&
          (code == 'email_exists' ||
              code == 'user_already_exists' ||
              detail.contains('already registered') ||
              detail.contains('already exists'))) {
        return usernameOnly
            ? 'That username already has an account. Choose Sign in, or use another username.'
            : 'That email may already be registered. Try signing in, or use another email address.';
      }
      if (error is AuthRetryableFetchException) {
        return 'Could not reach the account service. Check the internet connection and try again.';
      }
      if (signingUp && code.isNotEmpty) {
        return kDebugMode
            ? 'Account creation failed (error code: $code).'
            : 'Could not create the account. Check your connection and try again.';
      }
    }

    // Keep sign-in failures deliberately indistinguishable so they do not
    // disclose whether a username has an account.
    if (signingUp && kDebugMode) {
      return 'Account setup failed (${error.runtimeType}). Check your connection and try again.';
    }
    return signingUp
        ? 'Could not create the account. Check your connection and try again.'
        : usernameOnly
        ? 'Sign-in failed. Check your username and password.'
        : 'Sign-in failed. Check your email and password.';
  }

  static bool _configurationFailure(Object error) {
    if (error is! AuthException) return false;
    final code = error.code?.toLowerCase() ?? '';
    final detail = error.message.toLowerCase();
    return code == 'bad_jwt' ||
        detail.contains('invalid api key') ||
        detail.contains('invalid project url') ||
        detail.contains('project not found');
  }

  static Future<void> signIn(String identifier, String password) async {
    final normalizedIdentifier = usernameOnly
        ? internalEmailForUsername(identifier)
        : normalizeEmail(identifier);
    if (normalizedIdentifier == null || password.isEmpty || client == null) {
      throw StateError('Unable to sign in');
    }
    await client!.auth
        .signInWithPassword(email: normalizedIdentifier, password: password)
        .timeout(requestTimeout);
  }

  static Future<bool> signUp(
    String username,
    String password, {
    String? email,
  }) async {
    final name = normalize(username);
    final normalizedEmail = usernameOnly
        ? (name == null ? null : internalEmailForUsername(name))
        : normalizeEmail(email ?? '');
    if (normalizedEmail == null ||
        name == null ||
        password.length < 8 ||
        client == null) {
      throw StateError('Unable to create account');
    }
    final result = await client!.auth
        .signUp(
          email: normalizedEmail,
          password: password,
          data: {'username': name},
        )
        .timeout(requestTimeout);
    return result.session != null;
  }

  static Future<void> signOut() async {
    await client?.auth.signOut();
  }
}
