import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings and the trial/unlock state. Backed by SharedPreferences.
class Settings extends ChangeNotifier {
  Settings._(this._p);
  final SharedPreferences _p;

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = Settings._(p);
    if (!p.containsKey('first_open')) {
      await p.setString('first_open', DateTime.now().toIso8601String());
      await p.setInt('verse_seed', Random().nextInt(1 << 30));
    }
    return s;
  }

  // identity
  String get name => _p.getString('name') ?? '';
  Future<void> setName(String v) => _set(() => _p.setString('name', v.trim()));

  DateTime get firstOpen => DateTime.parse(_p.getString('first_open')!);
  int get verseSeed => _p.getInt('verse_seed') ?? 7;

  // theme: auto | day | night
  String get themeMode => _p.getString('theme_mode') ?? 'auto';
  Future<void> setThemeMode(String v) => _set(() => _p.setString('theme_mode', v));

  // reminders, minutes since midnight; -1 = off
  int get morningAt => _p.getInt('t_morning') ?? 6 * 60;
  int get middayAt => _p.getInt('t_midday') ?? 12 * 60 + 30;
  int get eveningAt => _p.getInt('t_evening') ?? 21 * 60;
  Future<void> setReminder(String which, int minutes) => _set(() => _p.setInt('t_$which', minutes));

  // prayer slots
  int get prayerSlots => _p.getInt('prayer_slots') ?? 3;
  Future<void> setPrayerSlots(int n) => _set(() => _p.setInt('prayer_slots', n.clamp(1, 10)));

  // soundscape
  String get sound => _p.getString('sound') ?? 'rain';
  Future<void> setSound(String v) => _set(() => _p.setString('sound', v));
  double get volume => _p.getDouble('volume') ?? 0.55;
  Future<void> setVolume(double v) => _set(() => _p.setDouble('volume', v));

  // selah
  bool get selahFocus => _p.getBool('selah_focus') ?? true;
  Future<void> setSelahFocus(bool v) => _set(() => _p.setBool('selah_focus', v));

  // entitlement
  bool get unlocked => _p.getBool('unlocked') ?? false;
  Future<void> setUnlocked(bool v) => _set(() => _p.setBool('unlocked', v));
  static const trialDays = 7;
  int get trialDaysLeft => max(0, trialDays - DateTime.now().difference(firstOpen).inDays);
  bool get inTrial => trialDaysLeft > 0;
  /// Full use: trial or unlocked. After the trial, reading your own entries always works.
  bool get canWrite => unlocked || inTrial;

  Future<void> _set(Future<bool> Function() f) async {
    await f();
    notifyListeners();
  }
}
