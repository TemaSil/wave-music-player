import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/wave_theme.dart';
import '../../data/track.dart';
import 'artwork_image.dart';

/// The hero of the Now Playing screen: a squircle cover with a vinyl that
/// slides out from behind it and spins while the track is running.
///
/// Rotation is integrated by hand on a [Ticker] rather than driven by an
/// [AnimationController], because the disc has to ease its *speed* up and down
/// without ever jumping its *angle* — pausing mid-spin must decelerate from
/// wherever the groove happens to be.
class VinylArtwork extends StatefulWidget {
  const VinylArtwork({
    super.key,
    required this.track,
    required this.palette,
    required this.spinning,
    this.heroTag,
  });

  final Track track;
  final WavePalette palette;
  final bool spinning;
  final Object? heroTag;

  @override
  State<VinylArtwork> createState() => _VinylArtworkState();
}

// Geometry, as fractions of the square the widget is given. Each piece's
// half-width plus its offset must stay at or below 0.5, or the spun-out disc
// and the shifted cover clip against the edges of the box.
const double _kCoverSize = 0.84;
const double _kCoverShift = 0.08;
const double _kDiscSize = 0.72;
const double _kDiscShift = 0.14;

class _VinylArtworkState extends State<VinylArtwork>
    with SingleTickerProviderStateMixin {
  /// Radians turned per second at full speed (~33 rpm, slowed for calm).
  static const _fullSpeed = 0.62;

  late final Ticker _ticker;
  final ValueNotifier<double> _angle = ValueNotifier(0);
  double _speed = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    // Clamp dt so a dropped frame or a backgrounded app cannot fling the disc.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _lastTick = elapsed;

    final target = widget.spinning ? _fullSpeed : 0.0;
    // Exponential approach: frame-rate independent easing toward the target.
    _speed += (target - _speed) * (1 - math.exp(-dt * 2.4));
    if (_speed.abs() < 0.0005 && target == 0) {
      _speed = 0;
      return;
    }
    _angle.value = (_angle.value + dt * _speed) % (math.pi * 2);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _angle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.spinning ? 1.0 : 0.0),
      duration: WaveMotion.slow,
      curve: WaveMotion.emphasized,
      builder: (context, out, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            return SizedBox.square(
              dimension: side,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [_buildDisc(side, out), _buildCover(side, out)],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDisc(double side, double out) {
    final discSize = side * _kDiscSize;
    return Transform.translate(
      // Peeks out to the right as playback starts, tucks away when paused.
      offset: Offset(side * _kDiscShift * out, 0),
      child: Opacity(
        opacity: out,
        child: RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _angle,
            builder: (context, angle, child) =>
                Transform.rotate(angle: angle, child: child),
            child: SizedBox.square(
              dimension: discSize,
              child: CustomPaint(painter: _VinylPainter(widget.palette)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(double side, double out) {
    final radius = BorderRadius.circular(side * 0.10);
    // Shift left by half of what the disc shifts right, keeping the pair centred.
    Widget cover = Transform.translate(
      offset: Offset(-side * _kCoverShift * out, 0),
      child: SizedBox.square(
        dimension: side * _kCoverSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: widget.palette.primary.withValues(
                  alpha: 0.30 + 0.22 * out,
                ),
                blurRadius: 56,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRSuperellipse(
            borderRadius: radius,
            child: ArtworkImage(
              url: widget.track.artworkUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );

    if (widget.heroTag != null) {
      cover = Hero(
        tag: widget.heroTag!,
        // Keep the artwork square and un-stretched for the whole flight.
        flightShuttleBuilder: (_, animation, _, _, _) => ClipRSuperellipse(
          borderRadius: BorderRadius.circular(
            lerpDouble(12, side * 0.10, animation.value)!,
          ),
          child: CachedNetworkImage(
            imageUrl: widget.track.artworkUrl,
            fit: BoxFit.cover,
          ),
        ),
        child: cover,
      );
    }
    return cover;
  }
}

/// Concentric grooves, a colour-matched label and a highlight sweep.
class _VinylPainter extends CustomPainter {
  _VinylPainter(this.palette);

  final WavePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF1B1B22),
            Color(0xFF0A0A0F),
            Color(0xFF15151C),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.045);
    for (var r = radius * 0.42; r < radius * 0.97; r += radius * 0.038) {
      canvas.drawCircle(center, r, groove);
    }

    // Specular sweep — the reason the disc reads as spinning at all.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = SweepGradient(
          colors: [
            palette.secondary.withValues(alpha: 0.0),
            palette.secondary.withValues(alpha: 0.22),
            palette.primary.withValues(alpha: 0.0),
            palette.primary.withValues(alpha: 0.18),
            palette.secondary.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.18, 0.42, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Centre label.
    canvas.drawCircle(
      center,
      radius * 0.34,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primary, palette.tertiary],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.34)),
    );
    canvas.drawCircle(
      center,
      radius * 0.055,
      Paint()..color = WaveColors.abyss,
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.palette != palette;
}
