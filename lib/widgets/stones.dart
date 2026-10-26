import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/gratideo_theme.dart';

/// A small cairn. Five base stones always show; each answered prayer adds a gold
/// stone on top (up to 8 shown). A newly answered prayer drops in with a soft settle.
class StonesOfRemembrance extends StatelessWidget {
  const StonesOfRemembrance({super.key, required this.count, this.justAdded = 0, this.size = 150});
  final int count;
  final int justAdded;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final k = size / 150;
    final base = <(double, double, double, Color)>[
      (146, 28, 0, const Color(0xFFD9CBB0)),
      (122, 26, 24, const Color(0xFFCDBC9C)),
      (100, 24, 46, const Color(0xFFD6C7AA)),
      (80, 22, 66, const Color(0xFFC8B590)),
      (62, 20, 84, const Color(0xFFD2C2A2)),
    ];
    final tops = <(double, double, double)>[(50, 18, 100), (42, 16, 114), (34, 14, 126), (28, 12, 136), (22, 10, 144), (18, 9, 151), (14, 8, 157), (10, 7, 162)];
    final shown = count.clamp(0, tops.length);
    final children = <Widget>[];
    for (final b in base) {
      children.add(Positioned(bottom: b.$3 * k, child: _stone(b.$1 * k, b.$2 * k, g.isNight ? b.$4.withValues(alpha: 0.55) : b.$4)));
    }
    for (var i = 0; i < shown; i++) {
      final t = tops[i];
      Widget stone = _stone(t.$1 * k, t.$2 * k, g.gold);
      if (i >= shown - justAdded) {
        stone = stone.animate().moveY(begin: -140 * k, end: 0, duration: 620.ms, curve: Curves.easeOutBack).fadeIn(duration: 200.ms);
      }
      children.add(Positioned(bottom: t.$3 * k, child: stone));
    }
    return SizedBox(
      width: size,
      height: size + 24 * k,
      child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: children),
    );
  }

  Widget _stone(double w, double h, Color color) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
          boxShadow: const [BoxShadow(color: Color(0x1F1B2640), offset: Offset(0, 2), blurRadius: 0)],
        ),
      );
}
