import 'package:flutter_test/flutter_test.dart';
import 'package:gratideo/services/credentials.dart';

void main() {
  test('email is trimmed and lowercased', () {
    expect(normalizeEmail('  Mixed@Example.COM '), 'mixed@example.com');
  });

  test('salt is 16 bytes and stable per email', () {
    final salt = saltFor('Person@Example.com');
    expect(salt, hasLength(16));
    expect(salt, saltFor('person@example.com '));
    expect(saltFor('other@example.com'), isNot(salt));
  });

  test('verifier is deterministic for the same email and password', () {
    final a = deriveVerifier('person@example.com', 'correct horse', iterations: 1000);
    final b = deriveVerifier('Person@Example.com ', 'correct horse', iterations: 1000);
    expect(a, b);
    expect(a, hasLength(44));
    expect(deriveVerifier('person@example.com', 'wrong horse', iterations: 1000), isNot(a));
    expect(deriveVerifier('other@example.com', 'correct horse', iterations: 1000), isNot(a));
  });

  test('the shipped parameters derive a 32 byte key', () {
    final verifier = deriveVerifier('person@example.com', 'correct horse');
    expect(verifier, hasLength(44));
    expect(verifier, deriveVerifier('person@example.com', 'correct horse'));
  });
}

