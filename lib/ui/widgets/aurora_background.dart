import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/wave_theme.dart';

/// Slow-drifting colour field that sits behind every screen.
///
/// Four additive radial blobs orbit on incommensurate sine paths, so the
/// composition never visibly repeats. [energy] (driven by playback) widens and
/// speeds up the drift, which is what makes the app feel "alive" while a track
/// is running and settle down when it is paused.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.palette, this.energy = 0});

  final WavePalette palette;

  /// 0 = idle, 1 = playing.
  final double energy;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<WavePalette>(
      tween: WavePaletteTween(begin: widget.palette, end: widget.palette),
      duration: WaveMotion.palette,
      curve: Curves.easeInOutCubic,
      builder: (context, palette, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: widget.energy, end: widget.energy),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, energy, _) {
            return RepaintBoundary(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _AuroraPainter(
                    t: _drift.value,
                    palette: palette,
                    energy: energy,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.palette,
    required this.energy,
  });

  final double t;
  final WavePalette palette;
  final double energy;

  // (colour index, orbit x, orbit y, radius, speed, phase)
  static const _blobs = <(int, double, double, double, double, double)>[
    (0, 0.34, 0.24, 0.80, 1.00, 0.0),
    (1, 0.30, 0.30, 0.66, 0.74, 2.1),
    (2, 0.26, 0.22, 0.58, 1.32, 4.0),
    (0, 0.38, 0.18, 0.48, 0.53, 5.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = WaveColors.abyss);

    final colors = palette.all;
    final tau = math.pi * 2;
    // Playing widens the orbits and lifts the glow; idle pulls everything in.
    final spread = 0.75 + energy * 0.45;
    final lift = 0.30 + energy * 0.26;

    for (final (colorIndex, ax, ay, radiusFactor, speed, phase) in _blobs) {
      final angle = tau * t * speed + phase;
      final center = Offset(
        size.width * (0.5 + ax * spread * math.sin(angle)),
        size.height * (0.40 + ay * spread * math.cos(angle * 0.83 + phase)),
      );
      // A second, slower sine breathes the radius so blobs never look rigid.
      final radius =
          size.longestSide *
          radiusFactor *
          (0.85 + 0.15 * math.sin(angle * 0.61 + phase));

      final color = colors[colorIndex % colors.length];
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: lift),
              color.withValues(alpha: lift * 0.35),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Darken the extremes so glass chrome and text keep their contrast.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WaveColors.abyss.withValues(alpha: 0.55),
            WaveColors.abyss.withValues(alpha: 0.10),
            WaveColors.abyss.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.palette != palette || old.energy != energy;
}
