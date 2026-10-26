import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../theme/gratideo_theme.dart';
import '../widgets/common.dart';

/// The whole confession library by theme, with read-aloud and the
/// "Reign in Life" sequence (the original 13, played in order).
class ConfessionsScreen extends StatefulWidget {
  const ConfessionsScreen({super.key, this.initialId});
  final String? initialId;
  @override
  State<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends State<ConfessionsScreen> {
  final _tts = FlutterTts();
  String? _speakingId;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingId = null);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(Confession c) async {
    if (_speakingId == c.id) {
      await _tts.stop();
      setState(() => _speakingId = null);
      return;
    }
    await _tts.setSpeechRate(0.42);
    setState(() => _speakingId = c.id);
    await _tts.speak(c.confession);
  }

  Future<void> _speakReign() async {
    final ids = Content.instance.reignSet;
    final text = ids.map((id) => Content.instance.byId(id)?.confession ?? '').where((t) => t.isNotEmpty).join('. \n');
    setState(() => _speakingId = 'reign');
    await _tts.setSpeechRate(0.42);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final all = Content.instance.confessions;
    final themes = <String, List<Confession>>{};
    for (final c in all) {
      themes.putIfAbsent(c.theme, () => []).add(c);
    }
    const names = {
      'foundation': 'Foundation',
      'jesus-first': 'Jesus First',
      'identity': 'Who I Am in Christ',
      'faith-words': 'Faith and My Words',
      'victory': 'Strength and Victory',
      'healing': 'Healing and Life',
      'protection': 'Protection',
      'provision': 'Provision and the Work of My Hands',
      'wisdom': 'Wisdom and Guidance',
    };
    return Scaffold(
      appBar: AppBar(title: Text('Confessions', style: context.display.copyWith(fontSize: 24))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        children: [
          Text('Speak them aloud. From the Word, to your mouth, to your ears, to your mind.', style: context.body.copyWith(color: g.muted)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _speakingId == 'reign'
                ? () {
                    _tts.stop();
                    setState(() => _speakingId = null);
                  }
                : _speakReign,
            icon: Icon(_speakingId == 'reign' ? Icons.stop : Icons.play_arrow),
            label: Text(_speakingId == 'reign' ? 'Stop' : 'Play the 13 “Reign in Life” confessions'),
          ),
          for (final entry in themes.entries) ...[
            const SizedBox(height: 22),
            SectionLabel(names[entry.key] ?? entry.key),
            const SizedBox(height: 8),
            for (final c in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: context.body.copyWith(fontWeight: FontWeight.w600, color: c.id == widget.initialId ? g.goldText : g.ink)),
                            const SizedBox(height: 4),
                            Text(c.confession, style: context.body),
                            const SizedBox(height: 8),
                            for (final s in c.scripture) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${s.text} — ${s.ref} (BSB)', style: context.small)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _speakingId == c.id ? 'Stop' : 'Read aloud',
                        onPressed: () => _speak(c),
                        icon: Icon(_speakingId == c.id ? Icons.stop_circle_outlined : Icons.volume_up_outlined, color: g.goldText),
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
