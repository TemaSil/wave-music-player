import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/wave_theme.dart';

/// A mirrored bar visualiser.
///
/// The preview streams give us no FFT data, so the bars are synthesised from
/// three sine waves at incommensurate frequencies: the result reads as music
/// rather than as a loop. [active] fades the amplitude in and out, so pausing
/// settles the bars to a flat line instead of freezing them mid-motion.
class WaveVisualizer extends StatefulWidget {
  const WaveVisualizer({
    super.key,
    required this.palette,
    required this.active,
    this.barCount = 44,
    this.height = 68,
  });

  final WavePalette palette;
  final bool active;
  final int barCount;
  final double height;

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.active ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, amplitude, _) {
        return TweenAnimationBuilder<WavePalette>(
          tween: WavePaletteTween(begin: widget.palette, end: widget.palette),
          duration: WaveMotion.palette,
          builder: (context, palette, _) => RepaintBoundary(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => CustomPaint(
                size: Size(double.infinity, widget.height),
                painter: _VisualizerPainter(
                  t: _clock.value,
                  amplitude: amplitude,
                  palette: palette,
                  barCount: widget.barCount,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  _VisualizerPainter({
    required this.t,
    required this.amplitude,
    required this.palette,
    required this.barCount,
  });

  final double t;
  final double amplitude;
  final WavePalette palette;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    const tau = math.pi * 2;
    final slot = size.width / barCount;
    final barWidth = math.max(2.0, slot * 0.52);
    final centerY = size.height / 2;
    final colors = palette.all;

    for (var i = 0; i < barCount; i++) {
      final x = barCount == 1 ? 0.5 : i / (barCount - 1);

      // Three layers: a travelling wave, a faster ripple, and a slow swell.
      final travelling = 0.5 + 0.5 * math.sin(tau * t + x * 7.0);
      final ripple = 0.5 + 0.5 * math.sin(tau * t * 2.37 + x * 19.0 + 1.1);
      final swell = 0.5 + 0.5 * math.sin(tau * t * 0.41 + x * 2.3);
      final raw = travelling * 0.55 + ripple * 0.28 + swell * 0.17;

      // Taper the ends so the band reads as a shape, not a wall of bars.
      final envelope = math.pow(math.sin(math.pi * x).abs(), 0.55).toDouble();

      final rest = 0.05;
      final value = rest + (raw * envelope - rest).clamp(0.0, 1.0) * amplitude;
      final barHeight = (size.height * value).clamp(barWidth, size.height);

      // Blend across the full palette left-to-right.
      final position = x * (colors.length - 1);
      final lower = position.floor().clamp(0, colors.length - 1);
      final upper = (lower + 1).clamp(0, colors.length - 1);
      final color = Color.lerp(colors[lower], colors[upper], position - lower)!;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(slot * i + slot / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.35 + 0.55 * value)
          ..maskFilter = amplitude > 0.05
              ? MaskFilter.blur(BlurStyle.normal, 1.5 * amplitude)
              : null,
      );
    }
  }

  @override
  bool shouldRepaint(_VisualizerPainter old) =>
      old.t != t || old.amplitude != amplitude || old.palette != palette;
}
