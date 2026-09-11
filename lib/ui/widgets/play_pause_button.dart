import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_theme.dart';

/// Glass play/pause control that cross-fades its glyph and shows a ring while
/// the stream is still loading.
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    required this.accent,
    this.isBusy = false,
    this.size = 64,
  });

  final bool isPlaying;
  final bool isBusy;
  final VoidCallback onTap;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GlassButton.custom(
            onTap: onTap,
            width: size,
            height: size,
            label: isPlaying ? 'Pause' : 'Play',
            glowColor: accent,
            settings: LiquidGlassSettings(
              blur: 10,
              thickness: 26,
              glassColor: accent.withValues(alpha: 0.22),
              lightIntensity: 0.9,
              saturation: 1.7,
            ),
            child: AnimatedSwitcher(
              duration: WaveMotion.fast,
              switchInCurve: WaveMotion.overshoot,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  // A quarter turn on the way in makes the swap feel mechanical
                  // rather than like a plain cross-fade.
                  child: RotationTransition(
                    turns: Tween(begin: 0.12, end: 0.0).animate(animation),
                    child: child,
                  ),
                ),
              ),
              child: Icon(
                isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                key: ValueKey(isPlaying),
                size: size * 0.40,
                color: WaveColors.textPrimary,
              ),
            ),
          ),
          if (isBusy)
            IgnorePointer(
              child: SizedBox.square(
                dimension: size * 0.92,
                child: CupertinoActivityIndicator(
                  radius: size * 0.16,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
