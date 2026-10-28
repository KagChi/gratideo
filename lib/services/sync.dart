import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../data/settings.dart';
import 'api_client.dart';
import 'auth.dart';

/// Pushes local changes to D1 and applies whatever the other phones wrote.
/// One instance lives for the life of the app; screens ask it to refresh.
class SyncService extends ChangeNotifier {
  SyncService({required ApiClient api, required AuthService auth, required Settings settings})
      : _api = api,
        _auth = auth,
        _settings = settings;

  static SyncService? instance;

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
    try {
      final since = _settings.lastSyncFor(_auth.email) ?? '1970-01-01T00:00:00.000Z';
      final dirty = await Db.instance.dirtyRows();
      final body = await _api.post(
        '/v1/sync',
        body: {'since': since, ...dirty},
        token: token,
      );
      await Db.instance.markPushed(dirty);
      await Db.instance.applyRemote(body);
      final serverTime = body['serverTime'] as String?;
      if (serverTime != null) await _settings.setLastSyncFor(_auth.email, serverTime);
      _lastRun = DateTime.now();
      return true;
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

