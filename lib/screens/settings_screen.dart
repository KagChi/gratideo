import 'package:flutter/material.dart';

import '../services/reminders.dart';
import '../theme/gratideo_theme.dart';
import '../widgets/common.dart';
import '../widgets/auth_scope.dart';
import '../widgets/scope.dart';
import 'confessions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickTime(BuildContext context, String which, int current) async {
    final s = SettingsScope.of(context);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current < 0 ? 7 : current ~/ 60, minute: current < 0 ? 0 : current % 60));
    if (t == null) return;
    await s.setReminder(which, t.hour * 60 + t.minute);
    await Reminders.instance.requestPermission();
    await Reminders.instance.schedule(s);
  }

  String _fmt(int m) => m < 0 ? 'Off' : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final s = SettingsScope.of(context);
    final auth = AuthScope.of(context);
    final nameC = TextEditingController(text: s.name);
    Widget row(String title, String value, VoidCallback onTap, {VoidCallback? onOff}) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: context.body),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: context.body.copyWith(color: g.goldText, fontWeight: FontWeight.w600)),
              if (onOff != null) IconButton(tooltip: 'Turn off', onPressed: onOff, icon: Icon(Icons.notifications_off_outlined, size: 18, color: g.muted)),
            ],
          ),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: context.display.copyWith(fontSize: 24))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        children: [
          const SectionLabel('Account'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_circle_outlined, color: g.goldText),
            title: Text(auth.email, style: context.body),
            subtitle: Text('Signed in on this device', style: context.small),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, color: g.muted),
            title: Text('Sign out', style: context.body),
            onTap: () async {
              Navigator.of(context).pop();
              await auth.signOut();
            },
          ),
          const SizedBox(height: 18),
          const SectionLabel('Your name'),
          const SizedBox(height: 8),
          TextField(
            controller: nameC,
            decoration: const InputDecoration(hintText: 'How the greeting addresses you'),
            onSubmitted: s.setName,
            onTapOutside: (_) => s.setName(nameC.text),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Reminders'),
          row('Morning · Put Him first', _fmt(s.morningAt), () => _pickTime(context, 'morning', s.morningAt), onOff: () => s.setReminder('morning', -1).then((_) => Reminders.instance.schedule(s))),
          row('Midday · Look up', _fmt(s.middayAt), () => _pickTime(context, 'midday', s.middayAt), onOff: () => s.setReminder('midday', -1).then((_) => Reminders.instance.schedule(s))),
          row('Evening · Give thanks', _fmt(s.eveningAt), () => _pickTime(context, 'evening', s.eveningAt), onOff: () => s.setReminder('evening', -1).then((_) => Reminders.instance.schedule(s))),
          const SizedBox(height: 22),
          const SectionLabel('Look'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'auto', label: Text('By the clock')), ButtonSegment(value: 'day', label: Text('Morning Gold')), ButtonSegment(value: 'night', label: Text('Night Watch'))],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
          const SizedBox(height: 6),
          Text('By the clock: Morning Gold from 5:00, Night Watch from 18:00.', style: context.small),
          const SizedBox(height: 22),
          const SectionLabel('Prayer list'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Prayers on the list', style: context.body),
            subtitle: Text('Three keeps it focused. Up to ten.', style: context.small),
            trailing: DropdownButton<int>(
              value: s.prayerSlots,
              underline: const SizedBox.shrink(),
              items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (v) => v == null ? null : s.setPrayerSlots(v),
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Selah'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Silence notifications during Selah', style: context.body),
            subtitle: Text('Android: Do Not Disturb for the session. iPhone: the app guides you to a Selah Focus.', style: context.small),
            value: s.selahFocus,
            onChanged: s.setSelahFocus,
          ),
          const SizedBox(height: 22),
          const SectionLabel('Library'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('All confessions', style: context.body),
            trailing: Icon(Icons.chevron_right, color: g.muted),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConfessionsScreen())),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Gratideo'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.unlocked ? 'Unlocked for life' : s.inTrial ? 'Free trial · ${s.trialDaysLeft} day${s.trialDaysLeft == 1 ? '' : 's'} left' : 'Trial ended', style: context.body),
            subtitle: Text(s.unlocked ? 'Thank you. All future updates are included.' : 'One payment. No subscription, no ads.', style: context.small),
            trailing: s.unlocked ? Icon(Icons.check_circle, color: g.gold) : Icon(Icons.chevron_right, color: g.muted),
            onTap: s.unlocked ? null : () => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => const PaywallSheet()),
          ),
          const SizedBox(height: 12),
          Text('Scripture: Berean Standard Bible (BSB), public domain. Your prayers, thanksgivings and journal stay on this phone. Soundscapes are made for the app and never streamed.', style: context.small),
        ],
      ),
    );
  }
}
