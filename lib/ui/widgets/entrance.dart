import 'package:flutter/widgets.dart';

import '../../core/wave_theme.dart';

/// Fades and lifts a child into place, staggered by its position in a list.
///
/// The delay is capped so a long list never leaves the last rows waiting; past
/// the cap everything lands together.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = const Offset(0, 22),
    this.stagger = const Duration(milliseconds: 42),
    this.maxDelay = const Duration(milliseconds: 420),
  });

  final int index;
  final Widget child;
  final Offset offset;
  final Duration stagger;
  final Duration maxDelay;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WaveMotion.medium,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: WaveMotion.emphasized,
  );

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.stagger.inMilliseconds * widget.index).clamp(
      0,
      widget.maxDelay.inMilliseconds,
    );
    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: delayMs)).then((_) {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
