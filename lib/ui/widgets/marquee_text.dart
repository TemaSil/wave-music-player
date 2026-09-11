import 'package:flutter/widgets.dart';

/// Single-line text that scrolls itself when it does not fit.
///
/// Track and artist names routinely overflow in a mini-player, and truncating
/// them hides exactly the part that identifies the song. Text that fits is
/// rendered as a plain [Text] with no animation cost.
class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 26,
    this.pause = const Duration(milliseconds: 1600),
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;

  /// Scroll speed in logical pixels per second.
  final double velocity;

  /// How long to dwell at each end before travelling back.
  final Duration pause;

  /// Used only when the text fits and no scrolling is needed.
  final TextAlign textAlign;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  late Animation<double> _travel = const AlwaysStoppedAnimation(0);
  double _overflow = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Rebuilds the hold/scroll/hold/scroll-back cycle for a new overflow width.
  void _configure(double overflow) {
    if ((overflow - _overflow).abs() < 0.5 && _controller.isAnimating) return;
    _overflow = overflow;

    if (overflow <= 0.5) {
      _controller.stop();
      _controller.value = 0;
      _travel = const AlwaysStoppedAnimation(0);
      return;
    }

    final scrollMs = (overflow / widget.velocity * 1000)
        .clamp(900, 12000)
        .toInt();
    final pauseMs = widget.pause.inMilliseconds;
    final totalMs = scrollMs * 2 + pauseMs * 2;

    _travel = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: pauseMs.toDouble()),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: scrollMs.toDouble(),
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: pauseMs.toDouble()),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: scrollMs.toDouble(),
      ),
    ]).animate(_controller);

    _controller
      ..duration = Duration(milliseconds: totalMs)
      ..forward(from: 0)
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final overflow = painter.width - constraints.maxWidth;

        // Layout happens during build, so defer the controller work a frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _configure(overflow);
        });

        if (overflow <= 0.5) {
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            textAlign: widget.textAlign,
            overflow: TextOverflow.clip,
          );
        }

        return ClipRect(
          child: ShaderMask(
            // Fade the leading/trailing edge so text dissolves rather than cuts.
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.05, 0.92, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: AnimatedBuilder(
              animation: _travel,
              builder: (context, child) => Transform.translate(
                offset: Offset(-overflow * _travel.value, 0),
                child: child,
              ),
              child: SizedBox(
                width: painter.width,
                child: Text(
                  widget.text,
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
