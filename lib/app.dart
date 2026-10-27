import 'dart:async';

import 'package:flutter/material.dart';

import 'data/settings.dart';
import 'screens/auth_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/prayers_screen.dart';
import 'screens/remember_screen.dart';
import 'screens/selah_screen.dart';
import 'screens/thanks_screen.dart';
import 'screens/today_screen.dart';
import 'services/auth.dart';
import 'theme/gratideo_theme.dart';
import 'widgets/auth_scope.dart';
import 'widgets/scope.dart';

class GratideoApp extends StatefulWidget {
  const GratideoApp({super.key, required this.settings, required this.auth});
  final Settings settings;
  final AuthService auth;

  @override
  State<GratideoApp> createState() => _GratideoAppState();
}

class _GratideoAppState extends State<GratideoApp> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_refresh);
    widget.auth.addListener(_refresh);
    // Re-evaluate day/night once a minute so the switch happens on time.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.settings.removeListener(_refresh);
    widget.auth.removeListener(_refresh);
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(DateTime.now(), widget.settings.themeMode);
    return AuthScope(
      auth: widget.auth,
      child: SettingsScope(
        settings: widget.settings,
        child: MaterialApp(
          title: 'Gratideo',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(colors),
          home: widget.auth.isSignedIn ? const HomeShell() : AuthScreen(auth: widget.auth),
        ),
      ),
    );
  }
}

/// Bottom tabs on a phone; two panes when the Fold is open (width 600+).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _tabs = [
    (Icons.wb_sunny_outlined, 'Today'),
    (Icons.format_list_bulleted, 'Prayers'),
    (Icons.favorite_border, 'Thanks'),
    (Icons.menu_book_outlined, 'Journal'),
    (Icons.layers_outlined, 'Remember'),
  ];

  Widget _page(int i) => switch (i) {
        0 => const TodayScreen(),
        1 => const PrayersScreen(),
        2 => const ThanksScreen(),
        3 => const JournalScreen(),
        _ => const RememberScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final g = context.g;
    final nav = BottomNavigationBar(
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      items: [for (final t in _tabs) BottomNavigationBarItem(icon: Icon(t.$1), label: t.$2)],
    );
    final fab = FloatingActionButton.extended(
      heroTag: 'selah',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SelahScreen(), fullscreenDialog: true)),
      backgroundColor: g.isNight ? g.gold : g.primary,
      foregroundColor: g.isNight ? g.onPrimary : g.onPrimary,
      icon: Icon(Icons.radio_button_checked, color: g.isNight ? g.onPrimary : const Color(0xFFE3A857)),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selah', style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: 17, color: g.onPrimary)),
          Text('2-Min Inquire', style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: g.onPrimary.withValues(alpha: 0.85))),
        ],
      ),
    );

    if (!wide) {
      return Scaffold(body: _page(_tab), bottomNavigationBar: nav, floatingActionButton: _tab == 0 ? fab : null);
    }

    // Unfolded: Today on the left, the selected companion pane on the right.
    return Scaffold(
      body: Row(
        children: [
          Expanded(child: _page(0)),
          VerticalDivider(width: 1, color: g.hairline),
          Expanded(child: _page(_tab == 0 ? 3 : _tab)),
        ],
      ),
      bottomNavigationBar: nav,
      floatingActionButton: fab,
    );
  }
}
