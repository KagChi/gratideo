import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gratideo/services/api_client.dart';
import 'package:gratideo/services/auth.dart';
import 'package:gratideo/services/credentials.dart';
import 'package:gratideo/services/token_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String base = 'https://api.test';
const int iterations = 1000;
const String password = 'A-sample-password-123';

Map<String, dynamic> session(String email) => {
      'token': 'token-$email',
      'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'user': {'id': 'u1', 'email': email, 'name': 'Test User', 'createdAt': '2026-01-01T00:00:00.000Z'},
    };

Future<ApiAuthService> build(
  MockClient client, {
  TokenStore? store,
}) =>
    ApiAuthService.load(
      api: ApiClient(client: client, baseUrl: base),
      store: store ?? MemoryTokenStore(),
      iterations: iterations,
    );

void main() {
  test('register sends the derived verifier, never the password', () async {
    late http.Request captured;
    final store = MemoryTokenStore();
    final auth = await build(
      MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(session('test@example.com')), 201);
      }),
      store: store,
    );

    await auth.register(name: 'Test User', email: ' Test@Example.com ', password: password);

    expect(captured.url.path, '/v1/auth/register');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['name'], 'Test User');
    expect(body['email'], 'test@example.com');
    expect(body['verifier'], deriveVerifier('test@example.com', password, iterations: iterations));
    expect(body['verifier'], isNot(password));
    expect((body['kdf'] as Map)['algo'], 'pbkdf2-sha256');
    expect((body['kdf'] as Map)['iterations'], iterations);

    expect(auth.isSignedIn, isTrue);
    expect(auth.email, 'test@example.com');
    expect(await store.read(), isNotNull);
  });

  test('a taken email surfaces the server message and stays signed out', () async {
    final auth = await build(MockClient((request) async => http.Response(
          jsonEncode({
            'error': {'code': 'email_taken', 'message': 'An account with this email already exists.'}
          }),
          409,
        )));

    await expectLater(
      auth.register(name: 'Test User', email: 'taken@example.com', password: password),
      throwsA(isA<AuthException>().having(
        (error) => error.message,
        'message',
        contains('already exists'),
      )),
    );
    expect(auth.isSignedIn, isFalse);
  });

  test('a wrong password reports the credential error', () async {
    final auth = await build(MockClient((request) async => http.Response(
          jsonEncode({
            'error': {'code': 'invalid_credentials', 'message': 'Email or password is incorrect.'}
          }),
          401,
        )));

    await expectLater(
      auth.signIn(email: 'test@example.com', password: 'wrong-password'),
      throwsA(isA<AuthException>().having(
        (error) => error.message,
        'message',
        'Email or password is incorrect.',
      )),
    );
    expect(auth.isSignedIn, isFalse);
  });

  test('a stored session restores on start', () async {
    final store = MemoryTokenStore(jsonEncode({
      'token': 'stored-token',
      'email': 'kept@example.com',
      'expiresAt': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    }));

    final auth = await build(MockClient((request) async => http.Response('{}', 200)), store: store);

    expect(auth.isSignedIn, isTrue);
    expect(auth.email, 'kept@example.com');
  });

  test('an expired stored session is dropped', () async {
    final store = MemoryTokenStore(jsonEncode({
      'token': 'old-token',
      'email': 'kept@example.com',
      'expiresAt': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    }));

    final auth = await build(MockClient((request) async => http.Response('{}', 200)), store: store);

    expect(auth.isSignedIn, isFalse);
    expect(await store.read(), isNull);
  });

  test('refresh signs the user out when the server rejects the token', () async {
    final store = MemoryTokenStore(jsonEncode({
      'token': 'stale-token',
      'email': 'kept@example.com',
      'expiresAt': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    }));

    final auth = await build(
      MockClient((request) async => http.Response(
            jsonEncode({
              'error': {'code': 'unauthorized', 'message': 'Sign in to continue.'}
            }),
            401,
          )),
      store: store,
    );

    await auth.refresh();

    expect(auth.isSignedIn, isFalse);
    expect(await store.read(), isNull);
  });

  test('refresh keeps the session when offline', () async {
    final auth = await build(MockClient((request) async => throw http.ClientException('offline')));

    await auth.register(name: 'Test', email: 'off@example.com', password: password).catchError((_) {});

    final store = MemoryTokenStore(jsonEncode({
      'token': 'live-token',
      'email': 'off@example.com',
      'expiresAt': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    }));
    final restored = await build(
      MockClient((request) async => throw http.ClientException('offline')),
      store: store,
    );

    await restored.refresh();

    expect(restored.isSignedIn, isTrue);
    expect(restored.email, 'off@example.com');
  });

  test('sign out clears the session and revokes it on the server', () async {
    final paths = <String>[];
    final store = MemoryTokenStore();
    final auth = await build(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/logout')) return http.Response('', 204);
        return http.Response(jsonEncode(session('test@example.com')), 201);
      }),
      store: store,
    );

    await auth.register(name: 'Test', email: 'test@example.com', password: password);
    await auth.signOut();

    expect(paths, contains('/v1/auth/logout'));
    expect(auth.isSignedIn, isFalse);
    expect(auth.email, isEmpty);
    expect(await store.read(), isNull);
  });
}

