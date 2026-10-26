import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/focus.dart';
import '../theme/gratideo_theme.dart';
import '../widgets/common.dart';
import '../widgets/scope.dart';

/// 2-Min Inquire: a 10-second breathing cycle (4 in, 2 hold, 4 out) for two minutes,
/// notifications silenced, then "What is God saying?". Always shown in Night Watch.
class SelahScreen extends StatefulWidget {
  const SelahScreen({super.key});
  @override
  State<SelahScreen> createState() => _SelahScreenState();
}

enum _Status { idle, running, paused, done }

class _SelahScreenState extends State<SelahScreen> with SingleTickerProviderStateMixin {
  static const total = Duration(minutes: 2);
  static const cycleMs = 10000;

  _Status _status = _Status.idle;
  Duration _remaining = total;
  DateTime? _endAt;
  Timer? _tick;
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: cycleMs));
  final _decision = TextEditingController();
  final _note = TextEditingController();
  bool _saved = false;
  bool _quietOn = false;
  bool _hasDndAccess = false;

  @override
  void initState() {
    super.initState();
    FocusService.instance.hasAccess().then((v) {
      if (mounted) setState(() => _hasDndAccess = v);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _breath.dispose();
    _decision.dispose();
    _note.dispose();
    if (_quietOn) FocusService.instance.setQuiet(false);
    super.dispose();
  }

  int get _elapsedMs => (total - _remaining).inMilliseconds;
  int get _cycleMs => _elapsedMs % cycleMs;
  String get _phase => _status == _Status.done
      ? 'done'
      : _status == _Status.idle
          ? 'idle'
          : _cycleMs < 4000
              ? 'in'
              : _cycleMs < 6000
                  ? 'hold'
                  : 'out';

  Future<void> _start() async {
    final s = SettingsScope.of(context);
    if (s.selahFocus && FocusService.instance.supported) {
      if (await FocusService.instance.hasAccess()) {
        await FocusService.instance.setQuiet(true);
        _quietOn = true;
      }
    }
    _endAt = DateTime.now().add(_status == _Status.done ? total : _remaining);
    if (_status == _Status.done) _remaining = total;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final rem = _endAt!.difference(DateTime.now());
      if (rem <= Duration.zero) {
        _finish();
      } else {
        setState(() => _remaining = rem);
      }
    });
    _breath.value = _cycleMs / cycleMs;
    _breath.repeat();
    HapticFeedback.lightImpact();
    setState(() => _status = _Status.running);
  }

  void _pause() {
    _tick?.cancel();
    _breath.stop();
    setState(() => _status = _Status.paused);
  }

  Future<void> _finish() async {
    _tick?.cancel();
    _breath.stop();
    if (_quietOn) {
      await FocusService.instance.setQuiet(false);
      _quietOn = false;
    }
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _status = _Status.done);
  }

  Future<void> _save() async {
    if (_note.text.trim().isEmpty) return;
    if (!await ensureCanWrite(context)) return;
    await Db.instance.addEntry(EntryKind.selah, _note.text, decision: _decision.text.trim().isEmpty ? null : _decision.text.trim());
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final night = GColors.night;
    final theme = Theme.of(context);
    final settings = SettingsScope.of(context);
    final phase = _phase;
    final secs = _remaining.inSeconds + (_remaining.inMilliseconds % 1000 > 0 ? 1 : 0);
    final clock = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final left = switch (phase) { 'in' => 4 - _cycleMs ~/ 1000, 'hold' => 6 - _cycleMs ~/ 1000, 'out' => 10 - _cycleMs ~/ 1000, _ => 0 };
    final phaseLabel = _status == _Status.paused
        ? 'PAUSED'
        : switch (phase) { 'in' => 'INHALE · $left', 'hold' => 'HOLD · $left', 'out' => 'EXHALE · $left', 'done' => 'SELAH', _ => 'TWO MINUTES WITH HIM' };
    final (phrase, ref) = switch (phase) {
      'in' => ('As He is, so am I in this world.', '1 John 4:17'),
      'hold' => ('Jesus, You are my Anchor.', 'Hebrews 6:19'),
      'out' => ('Lord Jesus, is Your Spirit in this door, or is this my own ambition?', ''),
      'done' => ('“This is the way. Walk in it.”', 'Isaiah 30:21 · BSB'),
      _ => ('Bring the decision. Breathe with the circle, ask, and wait for His prompting.', ''),
    };

    final serif = theme.textTheme.headlineMedium!.copyWith(color: night.ink);
    final scripture = theme.textTheme.titleLarge!.copyWith(color: night.ink, fontSize: 20);
    final small = theme.textTheme.bodySmall!.copyWith(color: night.muted);
    final label = theme.textTheme.labelSmall!.copyWith(color: night.gold);

    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: night.background, extensions: [night]),
      child: Scaffold(
        backgroundColor: night.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.chevron_left, color: night.gold),
                    label: Text('Today', style: TextStyle(color: night.gold, fontSize: 15)),
                  ),
                  const Spacer(),
                  const SoundPill(),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selah', style: serif.copyWith(fontSize: 34)),
                        Text('Ask Him first. Then wait.', style: small.copyWith(fontSize: 14)),
                      ],
                    ),
                  ),
                  _FocusToggle(
                    on: settings.selahFocus,
                    supported: FocusService.instance.supported,
                    hasAccess: _hasDndAccess,
                    onChanged: (v) => settings.setSelahFocus(v),
                    onGrant: () => FocusService.instance.requestAccess(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_focusText(settings.selahFocus), style: small),
              const SizedBox(height: 14),
              TextField(
                controller: _decision,
                style: TextStyle(color: night.ink),
                decoration: InputDecoration(
                  hintText: 'What are you bringing to Him?',
                  hintStyle: TextStyle(color: night.muted),
                  filled: true,
                  fillColor: night.surface,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: night.hairline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: night.gold, width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: AnimatedBuilder(
                    animation: _breath,
                    builder: (context, _) {
                      final t = _status == _Status.running || _status == _Status.paused ? _breath.value : 0.0;
                      final scale = _breathScale(t);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 262 * (0.7 + 0.38 * (scale - 0.6) / 0.43),
                            height: 262 * (0.7 + 0.38 * (scale - 0.6) / 0.43),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [night.gold.withValues(alpha: 0.15 + 0.45 * (scale - 0.6) / 0.43), night.gold.withValues(alpha: 0)], stops: const [0, 0.7]),
                            ),
                          ),
                          Container(
                            width: 234 * scale,
                            height: 234 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: night.gold, width: 1.5),
                              gradient: RadialGradient(colors: [night.gold.withValues(alpha: 0.16), night.gold.withValues(alpha: 0.04)]),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(phaseLabel, style: label.copyWith(letterSpacing: 1.6)),
                              Text(clock, style: TextStyle(color: night.ink, fontSize: 30, fontWeight: FontWeight.w500, fontFeatures: const [FontFeature.tabularFigures()])),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 88,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Column(
                      key: ValueKey(phrase),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(phrase, textAlign: TextAlign.center, style: scripture),
                        if (ref.isNotEmpty) Text(ref, style: small),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: night.gold, foregroundColor: night.onPrimary),
                      onPressed: _status == _Status.running ? _pause : _start,
                      child: Text(switch (_status) { _Status.running => 'Pause', _Status.paused => 'Continue', _Status.done => 'Again', _ => 'Begin' }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: night.ink, side: BorderSide(color: night.hairline)),
                      onPressed: _status == _Status.idle ? null : _finish,
                      child: const Text('Amen'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('WHAT IS GOD SAYING?', style: label)),
                  TextButton(onPressed: _saved ? null : _save, child: Text(_saved ? 'Saved to journal' : 'Save', style: TextStyle(color: _saved ? night.muted : night.gold))),
                ],
              ),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) {
                  if (_saved) setState(() => _saved = false);
                },
                style: TextStyle(color: night.ink),
                decoration: InputDecoration(
                  hintText: 'Optional. A verse, a peace, a check in your spirit, a next step.',
                  hintStyle: TextStyle(color: night.muted),
                  filled: true,
                  fillColor: night.surface,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: night.hairline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: night.gold, width: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _focusText(bool on) {
    if (!on) return 'Notifications stay on.';
    if (!FocusService.instance.supported) return 'On iPhone, start your “Selah” Focus from Control Centre. Apps cannot silence other apps on iOS.';
    if (!_hasDndAccess) return 'Tap Focus to allow Do Not Disturb once. Then Selah silences everything except alarms until you say Amen.';
    return 'Notifications are silenced until you say Amen.';
  }

  /// 0..1 through the 10 s cycle -> circle scale: 0.6 -> 1.0 (4 s), hold (2 s), -> 0.6 (4 s).
  static double _breathScale(double t) {
    final ms = t * cycleMs;
    double k;
    if (ms < 4000) {
      k = ms / 4000;
    } else if (ms < 6000) {
      k = 1;
    } else {
      k = 1 - (ms - 6000) / 4000;
    }
    final eased = 0.5 - 0.5 * cos(pi * k);
    return 0.6 + 0.43 * eased;
  }
}

class _FocusToggle extends StatelessWidget {
  const _FocusToggle({required this.on, required this.supported, required this.hasAccess, required this.onChanged, required this.onGrant});
  final bool on;
  final bool supported;
  final bool hasAccess;
  final ValueChanged<bool> onChanged;
  final VoidCallback onGrant;
  @override
  Widget build(BuildContext context) {
    final night = GColors.night;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        if (supported && on && !hasAccess) {
          onGrant();
        } else {
          onChanged(!on);
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(color: night.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: night.hairline)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 16, color: night.ink),
            const SizedBox(width: 8),
            Text('Focus', style: TextStyle(color: night.ink, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 20,
              padding: const EdgeInsets.all(2),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(color: on ? night.gold : const Color(0xFF3A3F4A), borderRadius: BorderRadius.circular(10)),
              child: Container(width: 16, height: 16, decoration: BoxDecoration(color: on ? night.onPrimary : night.muted, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}
