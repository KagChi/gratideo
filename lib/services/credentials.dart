import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hashlib/hashlib.dart' show pbkdf2, sha256;

/// Version tag mixed into the salt so a future scheme can coexist.
const String kdfVersion = 'gratideo|v1|';
const int kdfIterations = 210000;
const String kdfAlgorithm = 'pbkdf2-sha256';

String normalizeEmail(String email) => email.trim().toLowerCase();

/// Deterministic per-account salt. It only has to be unique, not secret, so it
/// can be derived on the phone without asking the server for it.
List<int> saltFor(String email) {
  final digest = sha256.convert(utf8.encode(kdfVersion + normalizeEmail(email))).bytes;
  return digest.sublist(0, 16);
}

/// PBKDF2-SHA256 verifier. This value is what the server stores a peppered hash
/// of; the password itself never leaves the device.
String deriveVerifier(String email, String password, {int iterations = kdfIterations}) {
  final key = pbkdf2(utf8.encode(password), saltFor(email), iterations, 32).bytes;
  return base64Encode(key);
}

/// Same derivation, off the UI isolate.
Future<String> deriveVerifierInBackground(
  String email,
  String password, {
  int iterations = kdfIterations,
}) =>
    compute(_deriveTask, <String, String>{
      'email': email,
      'password': password,
      'iterations': '$iterations',
    });

String _deriveTask(Map<String, String> input) => deriveVerifier(
      input['email'] ?? '',
      input['password'] ?? '',
      iterations: int.tryParse(input['iterations'] ?? '') ?? kdfIterations,
    );

