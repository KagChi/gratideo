/// Plain data types. Dates are stored as ISO-8601 strings in SQLite.
enum PrayerStatus { praying, answered, waiting, surrendered }

PrayerStatus statusFrom(String s) => PrayerStatus.values.firstWhere((e) => e.name == s, orElse: () => PrayerStatus.praying);

class Prayer {
  Prayer({required this.id, required this.title, required this.status, required this.createdAt, this.answeredAt, this.testimony});
  final int id;
  final String title;
  final PrayerStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final String? testimony;

  int get daysPraying => (answeredAt ?? DateTime.now()).difference(createdAt).inDays + 1;

  factory Prayer.fromMap(Map<String, Object?> m) => Prayer(
        id: m['id'] as int,
        title: m['title'] as String,
        status: statusFrom(m['status'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        answeredAt: m['answered_at'] == null ? null : DateTime.parse(m['answered_at'] as String),
        testimony: m['testimony'] as String?,
      );
}

class Thanks {
  Thanks({required this.id, required this.text, required this.day});
  final int id;
  final String text;
  final String day; // yyyy-MM-dd
  factory Thanks.fromMap(Map<String, Object?> m) => Thanks(id: m['id'] as int, text: m['text'] as String, day: m['day'] as String);
}

enum EntryKind { journal, selah }

class Entry {
  Entry({required this.id, required this.kind, required this.text, required this.createdAt, this.decision});
  final int id;
  final EntryKind kind;
  final String text;
  final DateTime createdAt;
  final String? decision; // for Selah: what was brought to God
  factory Entry.fromMap(Map<String, Object?> m) => Entry(
        id: m['id'] as int,
        kind: (m['kind'] as String) == 'selah' ? EntryKind.selah : EntryKind.journal,
        text: m['text'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        decision: m['decision'] as String?,
      );
}

class Confession {
  Confession({required this.id, required this.theme, required this.title, required this.type, required this.confession, required this.short, required this.scripture});
  final String id;
  final String theme;
  final String title;
  final String type; // confession | prayer
  final String confession;
  final String short;
  final List<ScriptureRef> scripture;
  factory Confession.fromJson(Map<String, dynamic> j) => Confession(
        id: j['id'] as String,
        theme: j['theme'] as String,
        title: j['title'] as String,
        type: j['type'] as String,
        confession: j['confession'] as String,
        short: j['short'] as String,
        scripture: (j['scripture'] as List).map((s) => ScriptureRef(ref: s['ref'] as String, text: s['text'] as String)).toList(),
      );
}

class ScriptureRef {
  const ScriptureRef({required this.ref, required this.text});
  final String ref;
  final String text;
}

class Verse {
  const Verse({required this.id, required this.ref, required this.theme, required this.text});
  final String id;
  final String ref;
  final String theme;
  final String text;
  factory Verse.fromJson(Map<String, dynamic> j) => Verse(id: j['id'] as String, ref: j['ref'] as String, theme: j['theme'] as String, text: j['text'] as String);
}

String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
