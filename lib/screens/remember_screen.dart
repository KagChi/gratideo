import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../theme/gratideo_theme.dart';
import '../widgets/common.dart';
import '../widgets/stones.dart';
import 'journal_screen.dart';

/// The heart of the app: what God has done. "On this day" from 6 and 12 months
/// ago, plus "I need reminding" for low days.
class RememberScreen extends StatefulWidget {
  const RememberScreen({super.key});
  @override
  State<RememberScreen> createState() => _RememberScreenState();
}

class _RememberScreenState extends State<RememberScreen> {
  Remembrance? _six;
  Remembrance? _twelve;
  List<Prayer> _answered = [];
  int _thanksTotal = 0;
  bool _reminding = false;
  List<Thanks> _randomThanks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final six = await Db.instance.onThisDay(6);
    final twelve = await Db.instance.onThisDay(12);
    final answered = await Db.instance.answeredPrayers();
    final total = await Db.instance.thanksCount();
    if (mounted) setState(() {
      _six = six;
      _twelve = twelve;
      _answered = answered;
      _thanksTotal = total;
    });
  }

  Future<void> _remindMe() async {
    final d = await Db.instance.db;
    final rows = await d.query('thanks', orderBy: 'RANDOM()', limit: 5);
    setState(() {
      _randomThanks = rows.map(Thanks.fromMap).toList();
      _reminding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final empty = _answered.isEmpty && _thanksTotal == 0;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text('Remember', style: context.display),
          Text('He has never left you. Here is the proof.', style: context.body.copyWith(color: g.muted)),
          const SizedBox(height: 18),
          GCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StonesOfRemembrance(count: _answered.length, size: 120),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_answered.length} prayer${_answered.length == 1 ? '' : 's'} answered', style: context.body.copyWith(fontWeight: FontWeight.w600)),
                      Text('$_thanksTotal thing${_thanksTotal == 1 ? '' : 's'} thanked for', style: context.body.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('“Thus far the LORD has helped us.” 1 Samuel 7:12', style: context.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: empty ? null : _remindMe,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('I need reminding'),
          ),
          if (_reminding) ...[
            const SizedBox(height: 18),
            const SectionLabel('He has been faithful'),
            const SizedBox(height: 8),
            for (final p in _answered.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You prayed: ${p.title}', style: context.body),
                      Text('Answered ${DateFormat('d MMM yyyy').format(p.answeredAt!)}${p.testimony == null ? '' : ' · ${p.testimony}'}', style: context.small.copyWith(color: g.goldText)),
                    ],
                  ),
                ),
              ),
            for (final t in _randomThanks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GCard(padding: const EdgeInsets.all(14), child: Text('${t.day} · thankful for ${t.text}', style: context.body)),
              ),
          ],
          if (empty) ...[
            const SizedBox(height: 18),
            Text('As you give thanks and see prayers answered, this page fills with your own testimony.', style: context.body.copyWith(color: g.muted)),
          ],
          _OnThisDay(title: 'Six months ago', r: _six),
          _OnThisDay(title: 'One year ago', r: _twelve),
        ],
      ),
    );
  }
}

class _OnThisDay extends StatelessWidget {
  const _OnThisDay({required this.title, required this.r});
  final String title;
  final Remembrance? r;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    if (r == null || r!.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        SectionLabel('On this day · $title'),
        const SizedBox(height: 8),
        for (final p in r!.answered)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: GCard(padding: const EdgeInsets.all(14), child: Text('Answered: ${p.title}', style: context.body))),
        for (final t in r!.thanks)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: GCard(padding: const EdgeInsets.all(14), child: Text('Thankful for ${t.text}', style: context.body.copyWith(color: g.ink)))),
        for (final e in r!.selah) Padding(padding: const EdgeInsets.only(bottom: 8), child: EntryCard(entry: e)),
      ],
    );
  }
}
