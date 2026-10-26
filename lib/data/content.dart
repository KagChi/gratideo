import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'models.dart';
import 'settings.dart';

/// Bundled content: the confession library and the verse set (both BSB, public domain).
class Content {
  Content._();
  static final Content instance = Content._();

  List<Confession> confessions = [];
  List<Verse> verses = [];
  List<String> reignSet = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final c = jsonDecode(await rootBundle.loadString('assets/data/confessions.json')) as Map<String, dynamic>;
    confessions = (c['confessions'] as List).map((j) => Confession.fromJson(j as Map<String, dynamic>)).toList();
    final sets = (c['sets'] as List?) ?? [];
    if (sets.isNotEmpty) reignSet = ((sets.first as Map<String, dynamic>)['ids'] as List).cast<String>();
    final v = jsonDecode(await rootBundle.loadString('assets/data/verses.json')) as Map<String, dynamic>;
    verses = (v['verses'] as List).map((j) => Verse.fromJson(j as Map<String, dynamic>)).toList();
    _loaded = true;
  }

  /// Each user gets their own shuffle (seeded on first open) so the sequence
  /// never repeats until every verse has been shown.
  Verse verseFor(DateTime day, Settings s) {
    final order = _shuffled(verses.length, s.verseSeed);
    final idx = _dayNumber(day, s.firstOpen) % order.length;
    return verses[order[idx]];
  }

  /// A confession on the verse's theme when one exists, otherwise rotate.
  Confession confessionFor(DateTime day, Settings s) {
    final verse = verseFor(day, s);
    final themed = confessions.where((c) => _themeMatch(c.theme, verse.theme)).toList();
    final pool = themed.isNotEmpty ? themed : confessions.where((c) => c.type == 'confession').toList();
    final n = _dayNumber(day, s.firstOpen);
    return pool[(n * 7 + s.verseSeed) % pool.length];
  }

  Confession? byId(String id) {
    for (final c in confessions) {
      if (c.id == id) return c;
    }
    return null;
  }

  static bool _themeMatch(String confessionTheme, String verseTheme) {
    const map = {
      'god-first': ['jesus-first', 'foundation'],
      'gratitude': ['provision', 'jesus-first'],
      'trust': ['jesus-first', 'protection'],
      'wisdom': ['wisdom'],
      'humility': ['jesus-first'],
      'identity': ['identity'],
      'strength': ['victory', 'healing'],
      'peace': ['protection', 'jesus-first'],
      'love-and-others': ['identity'],
      'work-and-provision': ['provision'],
      'guidance': ['wisdom'],
      'faith': ['faith-words'],
      'rest': ['jesus-first', 'healing'],
      'remembrance': ['victory', 'faith-words'],
    };
    return (map[verseTheme] ?? const []).contains(confessionTheme);
  }

  static int _dayNumber(DateTime day, DateTime first) {
    final a = DateTime(day.year, day.month, day.day);
    final b = DateTime(first.year, first.month, first.day);
    return max(0, a.difference(b).inDays);
  }

  static List<int> _shuffled(int n, int seed) {
    final list = List<int>.generate(n, (i) => i);
    final r = Random(seed);
    for (var i = n - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
    return list;
  }
}
