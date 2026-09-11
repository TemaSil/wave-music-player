import 'package:flutter/widgets.dart';

import '../../core/wave_theme.dart';

/// Draggable progress bar with an iOS-26-style liquid grab.
///
/// Grabbing it swells the track and inflates the thumb into a glowing bead;
/// releasing lets both settle back. The widget is presentational: it reports
/// scrub fractions and leaves seeking to the caller.
class LiquidSeekBar extends StatefulWidget {
  const LiquidSeekBar({
    super.key,
    required this.progress,
    required this.buffered,
    required this.palette,
    required this.onScrub,
    required this.onScrubEnd,
    this.enabled = true,
  });

  /// Playback position as a 0..1 fraction.
  final double progress;

  /// Buffered position as a 0..1 fraction.
  final double buffered;
  final WavePalette palette;

  /// Called continuously while dragging, with the previewed fraction.
  final ValueChanged<double> onScrub;

  /// Called on release, with the final fraction.
  final ValueChanged<double> onScrubEnd;
  final bool enabled;

  @override
  State<LiquidSeekBar> createState() => _LiquidSeekBarState();
}

class _LiquidSeekBarState extends State<LiquidSeekBar>
    with SingleTickerProviderStateMixin {
  static const _restHeight = 6.0;
  static const _activeHeight = 12.0;
  static const _hitHeight = 40.0;

  late final AnimationController _grab = AnimationController(
    vsync: this,
    duration: WaveMotion.fast,
    reverseDuration: WaveMotion.medium,
  );
  late final Animation<double> _grabCurve = CurvedAnimation(
    parent: _grab,
    curve: WaveMotion.overshoot,
    reverseCurve: Curves.easeOutCubic,
  );

  double _width = 1;
  double _pending = 0;

  @override
  void dispose() {
    _grab.dispose();
    super.dispose();
  }

  double _fractionFor(double dx) => (dx / _width).clamp(0.0, 1.0);

  void _start(Offset local) {
    if (!widget.enabled) return;
    _grab.forward();
    _pending = _fractionFor(local.dx);
    widget.onScrub(_pending);
  }

  void _update(Offset local) {
    if (!widget.enabled) return;
    _pending = _fractionFor(local.dx);
    widget.onScrub(_pending);
  }

  void _end() {
    if (!widget.enabled) return;
    _grab.reverse();
    widget.onScrubEnd(_pending);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth <= 0 ? 1 : constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _start(d.localPosition),
          onHorizontalDragUpdate: (d) => _update(d.localPosition),
          onHorizontalDragEnd: (_) => _end(),
          onHorizontalDragCancel: _end,
          onTapDown: (d) => _start(d.localPosition),
          onTapUp: (_) => _end(),
          onTapCancel: _end,
          child: SizedBox(
            height: _hitHeight,
            child: TweenAnimationBuilder<WavePalette>(
              tween: WavePaletteTween(
                begin: widget.palette,
                end: widget.palette,
              ),
              duration: WaveMotion.palette,
              builder: (context, palette, _) => AnimatedBuilder(
                animation: _grabCurve,
                builder: (context, _) => CustomPaint(
                  size: Size(_width, _hitHeight),
                  painter: _SeekPainter(
                    progress: widget.progress.clamp(0.0, 1.0),
                    buffered: widget.buffered.clamp(0.0, 1.0),
                    grab: _grabCurve.value.clamp(0.0, 1.2),
                    palette: palette,
                    enabled: widget.enabled,
                    restHeight: _restHeight,
                    activeHeight: _activeHeight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekPainter extends CustomPainter {
  _SeekPainter({
    required this.progress,
    required this.buffered,
    required this.grab,
    required this.palette,
    required this.enabled,
    required this.restHeight,
    required this.activeHeight,
  });

  final double progress;
  final double buffered;
  final double grab;
  final WavePalette palette;
  final bool enabled;
  final double restHeight;
  final double activeHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final height = restHeight + (activeHeight - restHeight) * grab;
    final radius = Radius.circular(height / 2);
    final opacity = enabled ? 1.0 : 0.4;

    RRect bar(double fraction) => RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - height / 2, size.width * fraction, height),
      radius,
    );

    canvas.drawRRect(
      bar(1),
      Paint()..color = WaveColors.hairline.withValues(alpha: 0.10 * opacity),
    );
    canvas.drawRRect(
      bar(buffered),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.14 * opacity),
    );

    if (progress > 0) {
      final fill = bar(progress);
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            colors: [palette.secondary, palette.primary, palette.tertiary],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity),
      );
      // Glow under the filled section, strongest while grabbed.
      canvas.drawRRect(
        fill,
        Paint()
          ..color = palette.primary.withValues(
            alpha: (0.20 + 0.35 * grab) * opacity,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * grab),
      );
    }

    final thumbX = (size.width * progress).clamp(0.0, size.width);
    final thumbCenter = Offset(thumbX, centerY);
    final thumbRadius = (height / 2) + 3 + 6 * grab;

    canvas.drawCircle(
      thumbCenter,
      thumbRadius * 2.2,
      Paint()
        ..color = palette.primary.withValues(
          alpha: (0.18 + 0.35 * grab) * opacity,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 12 * grab),
    );
    canvas.drawCircle(
      thumbCenter,
      thumbRadius,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.grab != grab ||
      old.palette != palette ||
      old.enabled != enabled;
}
