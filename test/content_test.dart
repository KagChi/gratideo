import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gratideo/data/content.dart';
import 'package:gratideo/data/models.dart';
import 'package:gratideo/data/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'first_open': '2026-01-01T06:00:00.000',
      'verse_seed': 42,
    });
    settings = await Settings.load();
    await Content.instance.load();
  });

  test('bundled content loads from assets', () {
    expect(Content.instance.verses, isNotEmpty);
    expect(Content.instance.confessions, isNotEmpty);
    expect(Content.instance.reignSet, isNotEmpty);
    for (final v in Content.instance.verses) {
      expect(v.ref, isNotEmpty);
      expect(v.text, isNotEmpty);
      expect(v.theme, isNotEmpty);
    }
  });

  test('verse of the day walks the whole set before repeating', () {
    final verses = Content.instance.verses;
    final seen = <String>{};
    final first = DateTime(2026, 1, 1);
    for (var i = 0; i < verses.length; i++) {
      seen.add(Content.instance.verseFor(first.add(Duration(days: i)), settings).id);
    }
    expect(seen.length, verses.length);
    expect(
      Content.instance.verseFor(first, settings).id,
      Content.instance.verseFor(first.add(Duration(days: verses.length)), settings).id,
    );
  });

  test('verse of the day is stable within a day and differs across seeds', () {
    final day = DateTime(2026, 3, 4, 8);
    final a = Content.instance.verseFor(day, settings);
    final b = Content.instance.verseFor(DateTime(2026, 3, 4, 22), settings);
    expect(a.id, b.id);
  });

  test('confession of the day comes from the bundled library', () {
    final ids = Content.instance.confessions.map((c) => c.id).toSet();
    for (var i = 0; i < 30; i++) {
      final c = Content.instance.confessionFor(DateTime(2026, 1, 1).add(Duration(days: i)), settings);
      expect(ids, contains(c.id));
      expect(c.confession, isNotEmpty);
    }
  });

  test('dayKey pads to a sortable date', () {
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}

