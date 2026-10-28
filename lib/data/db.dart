import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Personal data lives in SQLite on the device and, when signed in, is mirrored
/// to D1 so the same account sees it on every phone.
///
/// Every row carries a uuid, an updated_at stamp and a dirty flag: the sync pass
/// pushes dirty rows, then applies whatever the server has that is newer.
class Db {
  Db._();
  static final Db instance = Db._();
  Database? _db;

  /// Called after every local write so the app can push it in the background.
  void Function()? onLocalWrite;

  void _afterWrite() => onLocalWrite?.call();

  static const List<String> syncedTables = ['prayers', 'thanks', 'entries'];

  static String newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'gratideo.db'),
      version: 2,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE prayers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            title TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'praying',
            created_at TEXT NOT NULL,
            answered_at TEXT,
            testimony TEXT,
            updated_at TEXT NOT NULL,
            deleted_at TEXT,
            dirty INTEGER NOT NULL DEFAULT 1
          )''');
        await d.execute('''
          CREATE TABLE thanks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            text TEXT NOT NULL,
            day TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT,
            dirty INTEGER NOT NULL DEFAULT 1
          )''');
        await d.execute('CREATE INDEX thanks_day ON thanks(day)');
        await d.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            kind TEXT NOT NULL,
            text TEXT NOT NULL,
            decision TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT,
            dirty INTEGER NOT NULL DEFAULT 1
          )''');
        for (final table in syncedTables) {
          await d.execute('CREATE UNIQUE INDEX ${table}_uuid ON $table(uuid)');
        }
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final table in syncedTables) {
            await d.execute('ALTER TABLE $table ADD COLUMN uuid TEXT');
            await d.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
            await d.execute('ALTER TABLE $table ADD COLUMN deleted_at TEXT');
            await d.execute('ALTER TABLE $table ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1');
            final rows = await d.query(table, columns: ['id']);
            for (final row in rows) {
              await d.update(
                table,
                {'uuid': newUuid(), 'updated_at': nowIso()},
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
            await d.execute('CREATE UNIQUE INDEX ${table}_uuid ON $table(uuid)');
          }
        }
      },
    );
    return _db!;
  }

  // ---- prayers ----
  Future<List<Prayer>> prayers({bool activeOnly = false}) async {
    final rows = await (await db).query(
      'prayers',
      where: activeOnly ? "status IN ('praying','waiting') AND deleted_at IS NULL" : 'deleted_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(Prayer.fromMap).toList();
  }

  Future<List<Prayer>> answeredPrayers() async {
    final rows = await (await db).query(
      'prayers',
      where: "status = 'answered' AND deleted_at IS NULL",
      orderBy: 'answered_at DESC',
    );
    return rows.map(Prayer.fromMap).toList();
  }

  Future<int> addPrayer(String title) async {
    final id = await (await db).insert('prayers', {
      'uuid': newUuid(),
      'title': title,
      'status': 'praying',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': nowIso(),
      'dirty': 1,
    });
    _afterWrite();
    return id;
  }

  Future<void> setPrayerStatus(int id, PrayerStatus status, {String? testimony}) async {
    final values = <String, Object?>{
      'status': status.name,
      'updated_at': nowIso(),
      'dirty': 1,
    };
    if (status == PrayerStatus.answered) {
      values['answered_at'] = DateTime.now().toIso8601String();
      values['testimony'] = testimony;
    }
    await (await db).update('prayers', values, where: 'id = ?', whereArgs: [id]);
    _afterWrite();
  }

  Future<void> deletePrayer(int id) async {
    await (await db).update(
      'prayers',
      {'deleted_at': nowIso(), 'updated_at': nowIso(), 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _afterWrite();
  }

  // ---- thanksgiving ----
  Future<List<Thanks>> thanksOn(String day) async {
    final rows = await (await db).query(
      'thanks',
      where: 'day = ? AND deleted_at IS NULL',
      whereArgs: [day],
      orderBy: 'id ASC',
    );
    return rows.map(Thanks.fromMap).toList();
  }

  /// Rewrites one day's list, reusing existing rows so edits do not look like a
  /// delete-and-recreate to the other phones.
  Future<void> saveThanks(String day, List<String> texts) async {
    final d = await db;
    final clean = texts.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    await d.transaction((t) async {
      final existing = await t.query(
        'thanks',
        where: 'day = ? AND deleted_at IS NULL',
        whereArgs: [day],
        orderBy: 'id ASC',
      );
      for (var i = 0; i < clean.length; i++) {
        if (i < existing.length) {
          final row = existing[i];
          if (row['text'] != clean[i]) {
            await t.update(
              'thanks',
              {'text': clean[i], 'updated_at': nowIso(), 'dirty': 1},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        } else {
          await t.insert('thanks', {
            'uuid': newUuid(),
            'text': clean[i],
            'day': day,
            'updated_at': nowIso(),
            'dirty': 1,
          });
        }
      }
      for (var i = clean.length; i < existing.length; i++) {
        await t.update(
          'thanks',
          {'deleted_at': nowIso(), 'updated_at': nowIso(), 'dirty': 1},
          where: 'id = ?',
          whereArgs: [existing[i]['id']],
        );
      }
    });
    _afterWrite();
  }

  Future<int> thanksCount() async {
    final r = await (await db).rawQuery('SELECT COUNT(*) AS n FROM thanks WHERE deleted_at IS NULL');
    return (r.first['n'] as int?) ?? 0;
  }

  Future<List<Thanks>> randomThanks(int limit) async {
    final rows = await (await db).query(
      'thanks',
      where: 'deleted_at IS NULL',
      orderBy: 'RANDOM()',
      limit: limit,
    );
    return rows.map(Thanks.fromMap).toList();
  }

  // ---- journal and selah ----
  Future<List<Entry>> entries({EntryKind? kind, int limit = 200}) async {
    final rows = await (await db).query(
      'entries',
      where: kind == null ? 'deleted_at IS NULL' : 'kind = ? AND deleted_at IS NULL',
      whereArgs: kind == null ? null : [kind.name],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(Entry.fromMap).toList();
  }

  Future<int> addEntry(EntryKind kind, String text, {String? decision}) async {
    final id = await (await db).insert('entries', {
      'uuid': newUuid(),
      'kind': kind.name,
      'text': text.trim(),
      'decision': decision,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': nowIso(),
      'dirty': 1,
    });
    _afterWrite();
    return id;
  }

  Future<void> deleteEntry(int id) async {
    await (await db).update(
      'entries',
      {'deleted_at': nowIso(), 'updated_at': nowIso(), 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _afterWrite();
  }

  // ---- remembrance ----
  /// Things from about [monthsAgo] months ago (a 7-day window), for "On this day".
  Future<Remembrance> onThisDay(int monthsAgo) async {
    final now = DateTime.now();
    final centre = DateTime(now.year, now.month - monthsAgo, now.day);
    final from = centre.subtract(const Duration(days: 3));
    final to = centre.add(const Duration(days: 4));
    final d = await db;
    final th = await d.query(
      'thanks',
      where: 'day >= ? AND day < ? AND deleted_at IS NULL',
      whereArgs: [dayKey(from), dayKey(to)],
    );
    final pr = await d.query(
      'prayers',
      where: "status = 'answered' AND answered_at >= ? AND answered_at < ? AND deleted_at IS NULL",
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
    );
    final se = await d.query(
      'entries',
      where: "kind = 'selah' AND created_at >= ? AND created_at < ? AND deleted_at IS NULL",
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
    );
    return Remembrance(
      monthsAgo: monthsAgo,
      thanks: th.map(Thanks.fromMap).toList(),
      answered: pr.map(Prayer.fromMap).toList(),
      selah: se.map(Entry.fromMap).toList(),
    );
  }

  // ---- sync plumbing ----
  /// Rows changed on this device since the last successful push, in the shape
  /// the Worker expects.
  Future<Map<String, List<Map<String, Object?>>>> dirtyRows() async {
    final d = await db;
    final out = <String, List<Map<String, Object?>>>{};

    out['prayers'] = (await d.query('prayers', where: 'dirty = 1')).map((r) => <String, Object?>{
          'uuid': r['uuid'],
          'title': r['title'],
          'status': r['status'],
          'createdAt': r['created_at'],
          'answeredAt': r['answered_at'],
          'testimony': r['testimony'],
          'updatedAt': r['updated_at'],
          'deletedAt': r['deleted_at'],
        }).toList();

    out['thanks'] = (await d.query('thanks', where: 'dirty = 1')).map((r) => <String, Object?>{
          'uuid': r['uuid'],
          'text': r['text'],
          'day': r['day'],
          'updatedAt': r['updated_at'],
          'deletedAt': r['deleted_at'],
        }).toList();

    out['entries'] = (await d.query('entries', where: 'dirty = 1')).map((r) => <String, Object?>{
          'uuid': r['uuid'],
          'kind': r['kind'],
          'text': r['text'],
          'decision': r['decision'],
          'createdAt': r['created_at'],
          'updatedAt': r['updated_at'],
          'deletedAt': r['deleted_at'],
        }).toList();

    return out;
  }

  /// Clears the dirty flag only for the exact versions that were accepted, so a
  /// write made while the request was in flight is still pushed next time.
  Future<void> markPushed(Map<String, List<Map<String, Object?>>> pushed) async {
    final d = await db;
    for (final table in syncedTables) {
      for (final row in pushed[table] ?? const <Map<String, Object?>>[]) {
        await d.update(
          table,
          {'dirty': 0},
          where: 'uuid = ? AND updated_at = ?',
          whereArgs: [row['uuid'], row['updatedAt']],
        );
      }
    }
  }

  /// Applies the server copy, keeping whichever version is newer.
  Future<void> applyRemote(Map<String, dynamic> payload) async {
    final d = await db;

    Future<void> merge(
      String table,
      List<dynamic> rows,
      Map<String, Object?> Function(Map<String, dynamic>) toValues,
    ) async {
      for (final raw in rows) {
        final row = (raw as Map).cast<String, dynamic>();
        final uuid = row['uuid'] as String;
        final remoteUpdated = (row['updatedAt'] as String?) ?? nowIso();
        final local = await d.query(table, columns: ['id', 'updated_at'], where: 'uuid = ?', whereArgs: [uuid]);
        final values = toValues(row)..['dirty'] = 0;
        if (local.isEmpty) {
          await d.insert(table, values);
        } else {
          final localUpdated = (local.first['updated_at'] as String?) ?? '';
          if (remoteUpdated.compareTo(localUpdated) > 0) {
            await d.update(table, values, where: 'uuid = ?', whereArgs: [uuid]);
          }
        }
      }
    }

    await merge('prayers', (payload['prayers'] as List?) ?? const [], (row) => {
          'uuid': row['uuid'],
          'title': row['title'],
          'status': row['status'],
          'created_at': row['createdAt'],
          'answered_at': row['answeredAt'],
          'testimony': row['testimony'],
          'updated_at': row['updatedAt'],
          'deleted_at': row['deletedAt'],
        });

    await merge('thanks', (payload['thanks'] as List?) ?? const [], (row) => {
          'uuid': row['uuid'],
          'text': row['text'],
          'day': row['day'],
          'updated_at': row['updatedAt'],
          'deleted_at': row['deletedAt'],
        });

    await merge('entries', (payload['entries'] as List?) ?? const [], (row) => {
          'uuid': row['uuid'],
          'kind': row['kind'],
          'text': row['text'],
          'decision': row['decision'],
          'created_at': row['createdAt'],
          'updated_at': row['updatedAt'],
          'deleted_at': row['deletedAt'],
        });
  }

  /// Signs the device out of sync bookkeeping; the rows stay so nothing is lost.
  Future<void> markAllDirty() async {
    final d = await db;
    for (final table in syncedTables) {
      await d.update(table, {'dirty': 1});
    }
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

