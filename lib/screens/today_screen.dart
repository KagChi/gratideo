import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../data/content.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../theme/gratideo_theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';
import 'confessions_screen.dart';
import 'settings_screen.dart';

/// The day's three moments on one screen: morning (verse, confession, prayers),
/// midday (short line, Selah), evening (thanks). The moment is chosen by the clock.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late int _moment; // 0 morning, 1 midday, 2 evening
  final _tts = FlutterTts();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    final h = DateTime.now().hour;
    _moment = h < 11 ? 0 : h < 17 ? 1 : 2;
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(0.95);
    setState(() => _speaking = true);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final s = SettingsScope.of(context);
    final now = DateTime.now();
    final verse = Content.instance.verseFor(now, s);
    final confession = Content.instance.confessionFor(now, s);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
        children: [
          Row(
            children: [
              Expanded(child: Text(DateFormat('EEEE, d MMMM').format(now).toUpperCase(), style: context.label)),
              const SoundPill(),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                icon: Icon(Icons.tune, color: g.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(greeting(now, s), style: context.display),
          const SizedBox(height: 4),
          Text(_moment == 2 ? 'Give thanks before you rest.' : 'Put Him first today.', style: context.body.copyWith(color: g.muted)),
          const SizedBox(height: 18),
          _MomentSwitch(value: _moment, onChanged: (v) => setState(() => _moment = v)),
          const SizedBox(height: 16),
          if (_moment != 2) ...[
            _VerseCard(verse: verse, key: ValueKey(verse.id)),
            const SizedBox(height: 12),
            _ConfessionCard(
              confession: confession,
              full: _moment == 0,
              speaking: _speaking,
              onSpeak: () => _speak(_moment == 0 ? confession.confession : confession.short),
              onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConfessionsScreen(initialId: confession.id))),
            ),
          ],
          if (_moment == 0) ...[
            const SizedBox(height: 18),
            _ActivePrayers(limit: s.prayerSlots),
          ],
          if (_moment == 1) ...[
            const SizedBox(height: 18),
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Before you decide'),
                  const SizedBox(height: 8),
                  Text('Ask Him first. Tap Selah for two minutes of waiting on God before your next decision, big or small.', style: context.body),
                ],
              ),
            ),
          ],
          if (_moment == 2) ...[
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const GoldRule(), Text('VERSE OF THE DAY', style: context.label)]),
                  const SizedBox(height: 10),
                  Text(verse.text, style: context.scripture),
                  const SizedBox(height: 10),
                  Text('${verse.ref} · BSB', style: context.small),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Evening'),
                  const SizedBox(height: 8),
                  Text('Three things to thank Him for, then a line in your journal. Both are in the Thanks and Journal tabs.', style: context.body),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MomentSwitch extends StatelessWidget {
  const _MomentSwitch({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    const labels = ['Morning', 'Midday', 'Evening'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: g.isNight ? g.surface : const Color(0xFFF0E9DA), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == value ? (g.isNight ? const Color(0xFF2A2E38) : g.primary) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: i == value ? FontWeight.w600 : FontWeight.w500, color: i == value ? (g.isNight ? g.ink : g.onPrimary) : g.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Verse of the day with the word-by-word reveal (600 ms rise, 55 ms stagger).
class _VerseCard extends StatelessWidget {
  const _VerseCard({super.key, required this.verse});
  final Verse verse;
  @override
  Widget build(BuildContext context) {
    final words = verse.text.split(' ');
    final reduce = MediaQuery.of(context).disableAnimations;
    return GCard(
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const GoldRule(), Text('VERSE OF THE DAY', style: context.label)]),
          const SizedBox(height: 10),
          Semantics(
            label: verse.text,
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 5,
                children: [
                  for (var i = 0; i < words.length; i++)
                    reduce
                        ? Text(words[i], style: context.scripture)
                        : Text(words[i], style: context.scripture)
                            .animate(delay: Duration(milliseconds: 350 + i * 55))
                            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                            .moveY(begin: 6, end: 0, duration: 600.ms, curve: Curves.easeOut),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('${verse.ref} · BSB', style: context.small)
              .animate(delay: Duration(milliseconds: 450 + words.length * 55))
              .fadeIn(duration: 500.ms),
        ],
      ),
    );
  }
}

class _ConfessionCard extends StatelessWidget {
  const _ConfessionCard({required this.confession, required this.full, required this.speaking, required this.onSpeak, required this.onOpen});
  final Confession confession;
  final bool full;
  final bool speaking;
  final VoidCallback onSpeak;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return GCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONFESSION · ${confession.title.toUpperCase()}', style: context.label),
                  const SizedBox(height: 6),
                  Text(full ? confession.confession : confession.short, style: context.body),
                  if (full) ...[
                    const SizedBox(height: 8),
                    Text(confession.scripture.map((s) => s.ref).join(' · '), style: context.small),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            tooltip: speaking ? 'Stop' : 'Read aloud',
            onPressed: onSpeak,
            style: IconButton.styleFrom(backgroundColor: g.primary, foregroundColor: g.onPrimary, minimumSize: const Size(44, 44)),
            icon: Icon(speaking ? Icons.stop : Icons.volume_up_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ActivePrayers extends StatelessWidget {
  const _ActivePrayers({required this.limit});
  final int limit;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return FutureBuilder<List<Prayer>>(
      future: Db.instance.prayers(activeOnly: true),
      builder: (context, snap) {
        final items = (snap.data ?? const <Prayer>[]).take(limit).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('Praying for', trailing: Text('${items.length} of $limit', style: context.small)),
            const SizedBox(height: 4),
            if (items.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Add up to $limit prayers in the Prayers tab. They stay here until He answers.', style: context.body.copyWith(color: g.muted))),
            for (final p in items)
              Container(
                height: 44,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: g.hairline))),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p.title, style: context.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('Day ${p.daysPraying}', style: context.small),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
