import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// All personal data lives on the device in one SQLite file. No account, no server.
class Db {
  Db._();
  static final Db instance = Db._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'gratideo.db'),
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE prayers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'praying',
            created_at TEXT NOT NULL,
            answered_at TEXT,
            testimony TEXT
          )''');
        await d.execute('''
          CREATE TABLE thanks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            day TEXT NOT NULL
          )''');
        await d.execute('CREATE INDEX thanks_day ON thanks(day)');
        await d.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            text TEXT NOT NULL,
            decision TEXT,
            created_at TEXT NOT NULL
          )''');
      },
    );
    return _db!;
  }

  // ---- prayers ----
  Future<List<Prayer>> prayers({bool activeOnly = false}) async {
    final rows = await (await db).query('prayers', where: activeOnly ? "status IN ('praying','waiting')" : null, orderBy: 'created_at ASC');
    return rows.map(Prayer.fromMap).toList();
  }

  Future<List<Prayer>> answeredPrayers() async {
    final rows = await (await db).query('prayers', where: "status = 'answered'", orderBy: 'answered_at DESC');
    return rows.map(Prayer.fromMap).toList();
  }

  Future<int> addPrayer(String title) async =>
      (await db).insert('prayers', {'title': title, 'status': 'praying', 'created_at': DateTime.now().toIso8601String()});

  Future<void> setPrayerStatus(int id, PrayerStatus status, {String? testimony}) async {
    final values = <String, Object?>{'status': status.name};
    if (status == PrayerStatus.answered) {
      values['answered_at'] = DateTime.now().toIso8601String();
      values['testimony'] = testimony;
    }
    await (await db).update('prayers', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePrayer(int id) async => (await db).delete('prayers', where: 'id = ?', whereArgs: [id]);

  // ---- thanksgiving ----
  Future<List<Thanks>> thanksOn(String day) async {
    final rows = await (await db).query('thanks', where: 'day = ?', whereArgs: [day], orderBy: 'id ASC');
    return rows.map(Thanks.fromMap).toList();
  }

  Future<void> saveThanks(String day, List<String> texts) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('thanks', where: 'day = ?', whereArgs: [day]);
      for (final text in texts.where((x) => x.trim().isNotEmpty)) {
        await t.insert('thanks', {'text': text.trim(), 'day': day});
      }
    });
  }

  Future<int> thanksCount() async {
    final r = await (await db).rawQuery('SELECT COUNT(*) AS n FROM thanks');
    return (r.first['n'] as int?) ?? 0;
  }

  // ---- journal and selah ----
  Future<List<Entry>> entries({EntryKind? kind, int limit = 200}) async {
    final rows = await (await db).query('entries', where: kind == null ? null : 'kind = ?', whereArgs: kind == null ? null : [kind.name], orderBy: 'created_at DESC', limit: limit);
    return rows.map(Entry.fromMap).toList();
  }

  Future<int> addEntry(EntryKind kind, String text, {String? decision}) async =>
      (await db).insert('entries', {'kind': kind.name, 'text': text.trim(), 'decision': decision, 'created_at': DateTime.now().toIso8601String()});

  Future<void> deleteEntry(int id) async => (await db).delete('entries', where: 'id = ?', whereArgs: [id]);

  // ---- remembrance ----
  /// Things from about [monthsAgo] months ago (a 7-day window), for "On this day".
  Future<Remembrance> onThisDay(int monthsAgo) async {
    final now = DateTime.now();
    final centre = DateTime(now.year, now.month - monthsAgo, now.day);
    final from = centre.subtract(const Duration(days: 3));
    final to = centre.add(const Duration(days: 4));
    final d = await db;
    final th = await d.query('thanks', where: 'day >= ? AND day < ?', whereArgs: [dayKey(from), dayKey(to)]);
    final pr = await d.query('prayers', where: "status = 'answered' AND answered_at >= ? AND answered_at < ?", whereArgs: [from.toIso8601String(), to.toIso8601String()]);
    final se = await d.query('entries', where: "kind = 'selah' AND created_at >= ? AND created_at < ?", whereArgs: [from.toIso8601String(), to.toIso8601String()]);
    return Remembrance(monthsAgo: monthsAgo, thanks: th.map(Thanks.fromMap).toList(), answered: pr.map(Prayer.fromMap).toList(), selah: se.map(Entry.fromMap).toList());
  }
}

class Remembrance {
  Remembrance({required this.monthsAgo, required this.thanks, required this.answered, required this.selah});
  final int monthsAgo;
  final List<Thanks> thanks;
  final List<Prayer> answered;
  final List<Entry> selah;
  bool get isEmpty => thanks.isEmpty && answered.isEmpty && selah.isEmpty;
}
