import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../theme/gratideo_theme.dart';
import '../services/sync.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';

/// Three things to thank God for today. Each line glows in turn when given.
class ThanksScreen extends StatefulWidget {
  const ThanksScreen({super.key});
  @override
  State<ThanksScreen> createState() => _ThanksScreenState();
}

class _ThanksScreenState extends State<ThanksScreen> {
  final _c = List.generate(3, (_) => TextEditingController());
  bool _given = false;
  bool _loaded = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _load();
    final changed = await (SyncService.instance?.sync() ?? Future.value(false));
    if (changed) await _load();
  }

  Future<void> _load() async {
    final today = await Db.instance.thanksOn(dayKey(DateTime.now()));
    final total = await Db.instance.thanksCount();
    for (var i = 0; i < 3 && i < today.length; i++) {
      _c[i].text = today[i].text;
    }
    if (mounted) setState(() {
      _given = today.isNotEmpty;
      _loaded = true;
      _total = total;
    });
  }

  Future<void> _give() async {
    if (!await ensureCanWrite(context)) return;
    final texts = _c.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList();
    if (texts.isEmpty) return;
    await Db.instance.saveThanks(dayKey(DateTime.now()), texts);
    final total = await Db.instance.thanksCount();
    setState(() {
      _given = true;
      _total = total;
    });
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    if (!_loaded) {
      return const ScreenSkeleton(title: 'Give thanks', subtitle: 'Small things count. He sees them all.');
    }
    const hints = ['Something small', 'Someone He sent', 'Something He did'];
    final filled = _c.where((c) => c.text.trim().isNotEmpty).length;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text('Give thanks', style: context.display),
          Text(_total == 0 ? 'Small things count. He sees them all.' : 'You have thanked Him for $_total things so far.', style: context.body.copyWith(color: g.muted)),
          const SizedBox(height: 22),
          SectionLabel('Three things I thank Him for', trailing: Text('$filled of 3', style: context.small)),
          const SizedBox(height: 10),
          if (!_loaded) const SizedBox(height: 180),
          if (_loaded)
            for (var i = 0; i < 3; i++)
              if (!_given || _c[i].text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _given
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: g.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: g.gold.withValues(alpha: 0.6))),
                          child: Row(
                            children: [
                              SizedBox(width: 18, child: Text('${i + 1}', style: context.scripture.copyWith(fontSize: 17, fontStyle: FontStyle.normal, color: g.goldText))),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_c[i].text, style: context.body)),
                            ],
                          ),
                        )
                          .animate(delay: Duration(milliseconds: i * 320))
                          .boxShadow(begin: const BoxShadow(color: Colors.transparent), end: BoxShadow(color: g.gold.withValues(alpha: 0.35), blurRadius: 26), duration: 500.ms)
                          .then()
                          .boxShadow(end: BoxShadow(color: g.gold.withValues(alpha: 0.12), blurRadius: 12), duration: 700.ms)
                      : TextField(
                          controller: _c[i],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: hints[i],
                            prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 8, top: 12), child: Text('${i + 1}', style: context.scripture.copyWith(fontSize: 17, fontStyle: FontStyle.normal, color: g.goldText))),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          ),
                        ),
                ),
          const SizedBox(height: 10),
          if (!_given) FilledButton(onPressed: filled == 0 ? null : _give, child: const Text('Give thanks')),
          if (_given) ...[
            GCard(
              child: Column(
                children: [
                  Text('Thank You, Lord.', style: context.display.copyWith(fontSize: 26)),
                  const SizedBox(height: 10),
                  Text('“Therefore my heart rejoices, and I give thanks to Him with my song.”', textAlign: TextAlign.center, style: context.scripture.copyWith(fontSize: 17)),
                  const SizedBox(height: 6),
                  Text('Psalm 28:7 · BSB', style: context.small),
                  const SizedBox(height: 14),
                  Text('Kept in Remember. A year from today, you will see these again.', textAlign: TextAlign.center, style: context.small),
                ],
              ),
            ).animate().fadeIn(delay: 1100.ms, duration: 600.ms).moveY(begin: 12, end: 0, delay: 1100.ms, duration: 600.ms, curve: Curves.easeOut),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => setState(() => _given = false), child: const Text('Edit today\'s three')),
          ],
        ],
      ),
    );
  }
}
