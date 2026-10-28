import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../data/settings.dart';
import 'api_client.dart';
import 'auth.dart';

/// Pushes local changes to D1 and walks the server's pages with a cursor, so a
/// large account never arrives in one response.
class SyncService extends ChangeNotifier {
  SyncService({required ApiClient api, required AuthService auth, required Settings settings})
      : _api = api,
        _auth = auth,
        _settings = settings;

  static SyncService? instance;

  /// Safety stop: a runaway server would otherwise loop forever.
  static const int maxPages = 25;

  final ApiClient _api;
  final AuthService _auth;
  final Settings _settings;

  bool _running = false;
  DateTime? _lastRun;
  String? _error;

  bool get isRunning => _running;
  DateTime? get lastRun => _lastRun;
  String? get error => _error;

  /// Returns true when the server sent something that changed the local copy.
  Future<bool> sync() async {
    final token = _auth.token;
    if (token == null || _running) return false;

    _running = true;
    _error = null;
    notifyListeners();

    var changed = false;
    try {
      var cursors = Map<String, String>.from(_settings.syncCursorsFor(_auth.email));
      final dirty = await Db.instance.dirtyRows();
      var firstPage = true;

      for (var page = 0; page < maxPages; page++) {
        final body = await _api.post(
          '/v1/sync',
          body: {
            'cursors': cursors,
            if (firstPage) ...dirty,
          },
          token: token,
        );

        if (firstPage) {
          await Db.instance.markPushed(dirty);
          firstPage = false;
        }

        changed = await Db.instance.applyRemote(body) || changed;

        final next = (body['cursors'] as Map?)?.map((key, value) => MapEntry('$key', '$value'));
        if (next != null) {
          cursors = Map<String, String>.from(next);
          await _settings.setSyncCursorsFor(_auth.email, cursors);
        }

        if (body['hasMore'] != true) break;
      }

      _lastRun = DateTime.now();
      return changed;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = 'Could not sync right now.';
      return false;
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

