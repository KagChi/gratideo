import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// Thin JSON client for the Gratideo Worker.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;
  static const Duration _timeout = Duration(seconds: 25);

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      _send('GET', path, token: token);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) =>
      _send('POST', path, body: body, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('Gratideo is taking too long to answer. Try again.');
    } on SocketException {
      throw const ApiException('No connection. Check your internet and try again.');
    } on http.ClientException {
      throw const ApiException('No connection. Check your internet and try again.');
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      return const <String, dynamic>{};
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('Unexpected answer from Gratideo.', statusCode: response.statusCode);
    }

    if (response.statusCode >= 400) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          (error['message'] as String?) ?? 'Something went wrong. Please try again.',
          statusCode: response.statusCode,
          code: error['code'] as String?,
        );
      }
      throw ApiException('Something went wrong. Please try again.', statusCode: response.statusCode);
    }

    return decoded;
  }
}
