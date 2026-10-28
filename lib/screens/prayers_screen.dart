import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../theme/gratideo_theme.dart';
import '../services/sync.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import '../widgets/scope.dart';
import '../widgets/stones.dart';

/// Prayers stay on the list until God answers. An answered prayer becomes a stone.
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});
  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  List<Prayer> _active = [];
  List<Prayer> _answered = [];
  int _justAnswered = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _reload();
    final changed = await (SyncService.instance?.sync() ?? Future.value(false));
    if (changed) await _reload();
  }

  Future<void> _reload() async {
    final a = await Db.instance.prayers(activeOnly: true);
    final d = await Db.instance.answeredPrayers();
    if (mounted) setState(() {
      _active = a;
      _answered = d;
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (!await ensureCanWrite(context)) return;
    if (!mounted) return;
    final slots = SettingsScope.of(context).prayerSlots;
    if (_active.length >= slots) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Your list holds $slots prayers. Keep it focused, or raise the limit in Settings.')));
      return;
    }
    final text = await _ask(context, title: 'What are you praying for?', hint: 'One line is enough');
    if (text == null || text.trim().isEmpty) return;
    await Db.instance.addPrayer(text.trim());
    await _reload();
  }

  Future<void> _answer(Prayer p) async {
    final testimony = await _ask(context, title: 'What did God do?', hint: 'Write it down so you remember', confirm: 'Mark answered');
    if (testimony == null) return;
    await Db.instance.setPrayerStatus(p.id, PrayerStatus.answered, testimony: testimony.trim().isEmpty ? null : testimony.trim());
    setState(() => _justAnswered += 1);
    await _reload();
  }

  Future<void> _setStatus(Prayer p, PrayerStatus s) async {
    await Db.instance.setPrayerStatus(p.id, s);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final slots = SettingsScope.of(context).prayerSlots;
    if (_loading) {
      return const ScreenSkeleton(title: 'Prayers', subtitle: 'Praying until He answers.');
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text('Prayers', style: context.display),
          Text('Praying until He answers.', style: context.body.copyWith(color: g.muted)),
          const SizedBox(height: 18),
          SectionLabel('Praying for', trailing: Text('${_active.length} of $slots', style: context.small)),
          const SizedBox(height: 8),
          GCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final p in _active)
                  _PrayerRow(
                    prayer: p,
                    onAnswered: () => _answer(p),
                    onStatus: (s) => _setStatus(p, s),
                    onDelete: () async {
                      await Db.instance.deletePrayer(p.id);
                      await _reload();
                    },
                  ),
                if (_active.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Nothing here yet. Bring Him the first one.', style: context.body.copyWith(color: g.muted))),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add a prayer')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StonesOfRemembrance(count: _answered.length, justAdded: _justAnswered),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STONES OF REMEMBRANCE', style: context.label),
                      const SizedBox(height: 6),
                      Text('${_answered.length}', style: context.display.copyWith(fontSize: 30)),
                      Text('prayers answered since you began', style: context.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_justAnswered > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
              child: Column(
                children: [
                  Text('“Thus far the LORD has helped us.”', textAlign: TextAlign.center, style: context.scripture.copyWith(fontSize: 19)),
                  Text('1 Samuel 7:12 · BSB', style: context.small),
                ],
              ).animate().fadeIn(delay: 500.ms, duration: 900.ms),
            ),
          if (_answered.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionLabel('Answered'),
            const SizedBox(height: 8),
            for (final p in _answered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle), child: Icon(Icons.check, size: 14, color: g.isNight ? g.onPrimary : Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, style: context.body),
                            Text('Answered ${DateFormat('d MMM yyyy').format(p.answeredAt!)} · after ${p.daysPraying} days', style: context.small.copyWith(color: g.goldText, fontWeight: FontWeight.w600)),
                            if (p.testimony != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p.testimony!, style: context.small.copyWith(color: g.ink))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.prayer, required this.onAnswered, required this.onStatus, required this.onDelete});
  final Prayer prayer;
  final VoidCallback onAnswered;
  final ValueChanged<PrayerStatus> onStatus;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final waiting = prayer.status == PrayerStatus.waiting;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: g.hairline))),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: g.gold, width: 2), color: waiting ? g.gold : Colors.transparent)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prayer.title, style: context.body),
                Text('${waiting ? 'Waiting' : 'Praying'} · day ${prayer.daysPraying}', style: context.small),
              ],
            ),
          ),
          TextButton(onPressed: onAnswered, child: const Text('Answered')),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: g.muted),
            onSelected: (v) {
              if (v == 'delete') onDelete();
              if (v == 'waiting') onStatus(PrayerStatus.waiting);
              if (v == 'praying') onStatus(PrayerStatus.praying);
              if (v == 'surrendered') onStatus(PrayerStatus.surrendered);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: waiting ? 'praying' : 'waiting', child: Text(waiting ? 'Back to praying' : 'Mark as waiting')),
              const PopupMenuItem(value: 'surrendered', child: Text('Surrender it to Him')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> _ask(BuildContext context, {required String title, required String hint, String confirm = 'Save'}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: Theme.of(ctx).textTheme.headlineMedium),
      content: TextField(controller: c, autofocus: true, maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(confirm)),
      ],
    ),
  );
}
