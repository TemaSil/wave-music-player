import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/wave_theme.dart';

/// The small "this row is playing" indicator: four bars that dance while
/// playing and rest at a flat line when paused.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    required this.color,
    required this.animating,
    this.size = 14,
    this.barCount = 4,
  });

  final Color color;
  final bool animating;
  final double size;
  final int barCount;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _clock.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating == oldWidget.animating) return;
    // One of these sits in every row of every list. Left repeating, a screen of
    // 25 rows kept 25 tickers alive to animate bars nobody was looking at.
    if (widget.animating) {
      _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.animating ? 1.0 : 0.0),
      duration: WaveMotion.fast,
      builder: (context, amplitude, _) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _EqualizerPainter(
              t: _clock.value,
              amplitude: amplitude,
              color: widget.color,
              barCount: widget.barCount,
            ),
          ),
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({
    required this.t,
    required this.amplitude,
    required this.color,
    required this.barCount,
  });

  final double t;
  final double amplitude;
  final Color color;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / barCount;
    final width = slot * 0.55;
    final paint = Paint()..color = color;

    for (var i = 0; i < barCount; i++) {
      // Each bar gets its own phase so they never move in lockstep.
      final phase = i * 1.9;
      final wave =
          0.5 + 0.5 * math.sin(math.pi * 2 * t * (1 + i * 0.17) + phase);
      final height = size.height * (0.18 + 0.82 * wave * amplitude);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            slot * i + (slot - width) / 2,
            size.height - height,
            width,
            height,
          ),
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.t != t || old.amplitude != amplitude || old.color != color;
}
