import 'package:flutter/material.dart';

import '../theme/gratideo_theme.dart';

/// A softly pulsing placeholder while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final shape = BorderRadius.circular(widget.radius);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.35 + 0.35 * _controller.value,
        child: child,
      ),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: g.hairline, borderRadius: shape),
      ),
    );
  }
}

/// Whole-screen placeholder: the page title and a few card blocks.
class ScreenSkeleton extends StatelessWidget {
  const ScreenSkeleton({super.key, required this.title, this.subtitle, this.rows = 4, this.rowHeight = 84});

  final String title;
  final String? subtitle;
  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text(title, style: context.display),
          if (subtitle != null) const Skeleton(height: 14, width: 220),
          const SizedBox(height: 20),
          for (var i = 0; i < rows; i++) ...[
            Skeleton(height: rowHeight, radius: 16),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

