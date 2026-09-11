import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../core/wave_theme.dart';

/// Heart toggle with a burst: the icon overshoots and a ring of sparks fans out.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.onTap,
    this.size = 22,
    this.color = WaveColors.textSecondary,
    this.likedColor = const Color(0xFFFF4D6D),
  });

  final bool liked;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final Color likedColor;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only celebrate on the way in.
    if (widget.liked && !oldWidget.liked) _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 2.1;
    return Semantics(
      button: true,
      toggled: widget.liked,
      label: widget.liked ? 'Remove from library' : 'Add to library',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: box,
          height: box,
          child: AnimatedBuilder(
            animation: _burst,
            builder: (context, child) {
              final t = _burst.value;
              // Quick punch out, slow settle back.
              final pop = t < 0.35
                  ? 1 + 0.45 * Curves.easeOutBack.transform(t / 0.35)
                  : 1 +
                        0.45 *
                            (1 -
                                Curves.easeOutCubic.transform(
                                  (t - 0.35) / 0.65,
                                ));
              return CustomPaint(
                painter: _SparkPainter(progress: t, color: widget.likedColor),
                child: Center(
                  child: Transform.scale(
                    scale: widget.liked ? pop : 1.0,
                    child: child,
                  ),
                ),
              );
            },
            child: AnimatedSwitcher(
              duration: WaveMotion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                widget.liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                key: ValueKey(widget.liked),
                size: widget.size,
                color: widget.liked ? widget.likedColor : widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _sparkCount = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final distance =
        size.shortestSide * 0.30 + size.shortestSide * 0.28 * eased;
    // Fade out over the back half of the burst.
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.9;
    final paint = Paint()..color = color.withValues(alpha: opacity);

    for (var i = 0; i < _sparkCount; i++) {
      final angle = math.pi * 2 * i / _sparkCount - math.pi / 2;
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(offset, 1.8 * (1 - eased) + 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.color != color;
}
