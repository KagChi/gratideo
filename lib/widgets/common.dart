import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../services/purchases.dart';
import '../services/soundscape.dart';
import '../theme/gratideo_theme.dart';
import 'scope.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(text.toUpperCase(), style: context.label)),
          if (trailing != null) trailing!,
        ],
      );
}

class GCard extends StatelessWidget {
  const GCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.shadow = false});
  final Widget child;
  final EdgeInsets padding;
  final bool shadow;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: g.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.hairline),
        boxShadow: shadow && !g.isNight ? [BoxShadow(color: g.ink.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))] : null,
      ),
      child: child,
    );
  }
}

/// Small gold rule used before a section label (design token "Gold shapes").
class GoldRule extends StatelessWidget {
  const GoldRule({super.key});
  @override
  Widget build(BuildContext context) => Container(width: 18, height: 2, color: context.g.gold, margin: const EdgeInsets.only(right: 8));
}

/// The compact soundscape control shown on Today and Selah.
class SoundPill extends StatelessWidget {
  const SoundPill({super.key});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return ListenableBuilder(
      listenable: Soundscape.instance,
      builder: (context, _) {
        final s = Soundscape.instance;
        return Container(
          height: 44,
          decoration: BoxDecoration(color: g.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: g.hairline)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => showSoundSheet(context),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Row(
                    children: [
                      Icon(s.playing ? Icons.graphic_eq : Icons.music_note_outlined, size: 16, color: g.goldText),
                      const SizedBox(width: 8),
                      Text(s.mode.short, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: s.playing ? 'Pause soundscape' : 'Play soundscape',
                onPressed: s.toggle,
                icon: Icon(s.playing ? Icons.pause : Icons.play_arrow, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showSoundSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => const _SoundSheet(),
  );
}

class _SoundSheet extends StatelessWidget {
  const _SoundSheet();
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: Soundscape.instance,
      builder: (context, _) {
        final s = Soundscape.instance;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Soundscape', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text('Made for the app, never streamed. Keeps playing while you pray, read or wait.', style: context.small),
              const SizedBox(height: 14),
              for (final m in soundModes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      s.setMode(m.id);
                      settings.setSound(m.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: m.id == s.modeId ? g.gold : g.hairline),
                        color: m.id == s.modeId ? g.gold.withValues(alpha: 0.10) : g.surface,
                      ),
                      child: Row(
                        children: [
                          Icon(m.id == s.modeId ? Icons.radio_button_checked : Icons.radio_button_off, color: m.id == s.modeId ? g.gold : g.muted, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                Text(m.about, style: context.small),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('VOLUME', style: context.label)),
                  Text('${(s.volume * 100).round()}%', style: context.small),
                ],
              ),
              Slider(
                value: s.volume,
                onChanged: (v) => s.setVolume(v),
                onChangeEnd: (v) => settings.setVolume(v),
              ),
              FilledButton(
                onPressed: s.toggle,
                child: Text(s.playing ? 'Pause' : 'Play ${s.mode.name}'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Call before any write. Returns true when the user may continue.
Future<bool> ensureCanWrite(BuildContext context) async {
  final settings = SettingsScope.of(context);
  if (settings.canWrite) return true;
  await showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => const PaywallSheet());
  return settings.canWrite;
}

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});
  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = Purchases.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Keep walking with Him', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            settings.inTrial
                ? 'Your free trial has ${settings.trialDaysLeft} day${settings.trialDaysLeft == 1 ? '' : 's'} left.'
                : 'Your 7-day trial has ended. Everything you wrote stays yours to read. Unlock once to keep writing, with all future updates included.',
            style: context.body,
          ),
          const SizedBox(height: 16),
          for (final line in const ['Confessions, verse of the day and Selah', 'Prayer list, thanksgiving and journal', 'Remembrance: your own record of His faithfulness', 'No subscription. No ads. Nothing leaves your phone.'])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [Icon(Icons.check, size: 18, color: context.g.gold), const SizedBox(width: 10), Expanded(child: Text(line, style: context.body))]),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () => _run(p.buy),
            child: Text('Unlock for life · ${p.priceLabel}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : () => _run(p.restore), child: const Text('Restore purchase')),
          if (p.lastError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(p.lastError!, style: context.small)),
        ],
      ),
    );
  }
}

String greeting(DateTime now, Settings s) {
  final h = now.hour;
  final part = h < 12 ? 'morning' : h < 18 ? 'afternoon' : 'evening';
  final name = s.name.isEmpty ? '' : ', ${s.name}';
  return 'Good $part$name';
}
