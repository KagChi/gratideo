import 'dart:io';

import 'package:flutter/services.dart';

/// Silences notifications during Selah.
/// Android: Do Not Disturb through a small platform channel (needs one-time access grant).
/// iOS: apps cannot control Focus; the app guides the user to a "Selah" Focus instead.
class FocusService {
  FocusService._();
  static final FocusService instance = FocusService._();
  static const _ch = MethodChannel('gratideo/focus');

  bool get supported => Platform.isAndroid;

  Future<bool> hasAccess() async {
    if (!supported) return false;
    try {
      return (await _ch.invokeMethod<bool>('hasAccess')) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system screen where the user grants Do Not Disturb access.
  Future<void> requestAccess() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('requestAccess');
    } on PlatformException {
      // ignore: the settings screen simply does not open
    }
  }

  /// true = silence everything except alarms; false = restore normal.
  Future<void> setQuiet(bool on) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('setQuiet', {'on': on});
    } on PlatformException {
      // no access yet; Selah still runs, just without silence
    }
  }
}
