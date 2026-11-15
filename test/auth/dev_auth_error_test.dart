import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dear_diary/auth/dev_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('DevAuth safe auth diagnostics', () {
    test('username-only aliases are scoped to the Supabase project host', () {
      expect(
        DevAuth.internalEmailForUsername(
          'User1',
          projectUrl: 'https://project-ref.supabase.co',
        ),
        'user1@project-ref.supabase.co',
      );
    });

    test(
      'signup explains an existing email without exposing provider text',
      () {
        final message = DevAuth.safeFailureMessage(
          const AuthApiException(
            'User user1@auth.deardiary.invalid already registered',
            code: 'email_exists',
          ),
          signingUp: true,
        );

        expect(
          message,
          contains(
            DevAuth.usernameOnly ? 'already has an account' : 'already be registered',
          ),
        );
        expect(
          message,
          contains(DevAuth.usernameOnly ? 'Choose Sign in' : 'signing in'),
        );
        expect(message, isNot(contains('@auth.deardiary.invalid')));
      },
    );

    test('signup explains when email/password signup is disabled', () {
      final message = DevAuth.safeFailureMessage(
        const AuthApiException('Signup disabled', code: 'signup_disabled'),
        signingUp: true,
      );

      expect(message, contains('Account creation is currently unavailable'));
    });

    test('signup identifies rejected example and test email domains', () {
      final message = DevAuth.safeFailureMessage(
        const AuthApiException(
          'Example and test domains are not supported',
          code: 'email_address_invalid',
        ),
        signingUp: true,
      );

      expect(
        message,
        contains(
          DevAuth.usernameOnly
              ? 'This username could not be used'
              : 'Enter a valid email address',
        ),
      );
      expect(message, isNot(contains('@auth.deardiary.invalid')));
    });

    test('signup explains that the default SMTP service cannot send here', () {
      final message = DevAuth.safeFailureMessage(
        const AuthApiException(
          'Email address not authorized',
          code: 'email_address_not_authorized',
        ),
        signingUp: true,
      );

      expect(message, contains('confirmation message could not be sent'));
    });

    test(
      'signup email-send limit has a different fix from request throttling',
      () {
        final emailLimit = DevAuth.safeFailureMessage(
          const AuthApiException(
            'Email limit',
            code: 'over_email_send_rate_limit',
          ),
          signingUp: true,
        );
        final requestLimit = DevAuth.safeFailureMessage(
          const AuthApiException(
            'Request limit',
            code: 'over_request_rate_limit',
          ),
          signingUp: true,
        );

        expect(emailLimit, contains('Too many confirmation messages'));
        expect(requestLimit, contains('Too many attempts'));
        expect(requestLimit, isNot(emailLimit));
      },
    );

    test('signup timeout suggests signing in before retrying creation', () {
      final message = DevAuth.safeFailureMessage(
        TimeoutException('private transport detail'),
        signingUp: true,
      );

      expect(message, contains('try signing in'));
      expect(message, isNot(contains('private transport detail')));
      expect(message, isNot(contains('Supabase')));
    });

    test('signup identifies a rejected weak password', () {
      final message = DevAuth.safeFailureMessage(
        const AuthApiException('Password too weak', code: 'weak_password'),
        signingUp: true,
      );

      expect(message, contains('Choose a stronger password'));
    });

    test('unknown Auth failures show only the safe Supabase error code', () {
      final message = DevAuth.safeFailureMessage(
        const AuthApiException(
          'Sensitive provider detail user@example.com',
          code: 'hook_payload_invalid_content_type',
        ),
        signingUp: true,
      );

      expect(message, contains('hook_payload_invalid_content_type'));
      expect(message, isNot(contains('Sensitive provider detail')));
      expect(message, isNot(contains('user@example.com')));
    });

    test('bad project key gets configuration guidance', () {
      final message = DevAuth.safeFailureMessage(
        const AuthApiException('Invalid API key', code: 'bad_jwt'),
        signingUp: false,
      );

      expect(message, contains('configuration looks invalid'));
    });

    test('wrong sign-in details remain generic and identical', () {
      const wrongPassword = AuthApiException(
        'Invalid login credentials for user1',
        code: 'invalid_credentials',
      );
      const unknownUser = AuthApiException(
        'User not found: user2',
        code: 'user_not_found',
      );

      final first = DevAuth.safeFailureMessage(wrongPassword, signingUp: false);
      final second = DevAuth.safeFailureMessage(unknownUser, signingUp: false);

      expect(
        first,
        DevAuth.usernameOnly
            ? 'Sign-in failed. Check your username and password.'
            : 'Sign-in failed. Check your email and password.',
      );
      expect(second, first);
      expect(first, isNot(contains('user1')));
      expect(first, isNot(contains('user2')));
    });

    test('unconfirmed sign-in does not disclose account existence', () {
      final unconfirmed = DevAuth.safeFailureMessage(
        const AuthApiException(
          'Email not confirmed',
          code: 'email_not_confirmed',
        ),
        signingUp: false,
      );
      final wrongPassword = DevAuth.safeFailureMessage(
        const AuthApiException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
        signingUp: false,
      );

      expect(unconfirmed, wrongPassword);
    });
  });
}
