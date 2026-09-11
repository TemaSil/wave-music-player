import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../audio/player_service.dart';
import '../../core/wave_theme.dart';
import '../screens/now_playing_screen.dart';
import 'artwork_image.dart';
import 'marquee_text.dart';

/// The play pill, mounted in the tab bar's `bottomAccessory` slot — iOS 26's
/// `tabViewBottomAccessory`.
///
/// Built as a single [GlassButton.custom] on its own layer, the way the Apple
/// Music reference demo builds it: the bar positions the accessory but paints
/// no surface behind it, so the pill has to be its own piece of glass. It
/// reads [GlassTabBarAccessoryPlacementScope] and drops to a one-line layout
/// once the bar has collapsed and the pill has to share the row with the tab
/// indicator and the search capsule.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.player,
    required this.palette,
    required this.accent,
    this.onExpandBar,
  });

  final PlayerService player;
  final WavePalette palette;
  final Color accent;

  /// Called when the pill is tapped while the bar is collapsed: iOS scrolls
  /// back to the top and re-opens the bar rather than opening the player.
  final VoidCallback? onExpandBar;

  static const height = 50.0;

  @override
  Widget build(BuildContext context) {
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final placement = GlassTabBarAccessoryPlacementScope.of(context);
    final inline = placement == GlassTabBarAccessoryPlacement.inline;

    return Semantics(
      button: true,
      label:
          'Now playing: ${track.title} by ${track.artist}. Open the full player.',
      child: GlassButton.custom(
        onTap: () {
          if (inline && onExpandBar != null) {
            onExpandBar!();
          } else {
            Navigator.of(context).push(NowPlayingRoute());
          }
        },
        width: double.infinity,
        height: height,
        useOwnLayer: true,
        quality: GlassQuality.premium,
        shape: const LiquidRoundedRectangle(borderRadius: height / 2),
        settings: appleMusicGlass(alpha: 0.80),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inline ? 12 : 16),
          child: Row(
            children: [
              Hero(
                tag: kNowPlayingHeroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: inline ? 28 : 32,
                    child: ArtworkImage(url: track.thumbnailUrl, iconSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: inline
                    ? SizedBox(
                        height: 17,
                        child: MarqueeText(
                          track.title,
                          style: WaveText.body.copyWith(fontSize: 13),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 17,
                            child: MarqueeText(
                              track.title,
                              style: WaveText.body.copyWith(fontSize: 14),
                            ),
                          ),
                          SizedBox(
                            height: 15,
                            child: MarqueeText(
                              track.artist,
                              style: WaveText.caption.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 6),
              _Glyph(
                icon: player.isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                label: player.isPlaying ? 'Pause' : 'Play',
                size: 22,
                onTap: player.toggle,
              ),
              if (!inline)
                _Glyph(
                  icon: CupertinoIcons.forward_end_fill,
                  label: 'Next track',
                  size: 19,
                  color: WaveColors.textSecondary,
                  onTap: player.next,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bare glyph. The pill is already glass, and the package's guidance is that
/// interactive glass controls are not meant to sit inside another glass
/// surface — that is what gave the old pill its muddy double-refracted buttons.
class _Glyph extends StatefulWidget {
  const _Glyph({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 22,
    this.color = WaveColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final Color color;

  @override
  State<_Glyph> createState() => _GlyphState();
}

class _GlyphState extends State<_Glyph> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _pressed ? 0.84 : 1.0,
          duration: WaveMotion.fast,
          curve: WaveMotion.emphasized,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: AnimatedSwitcher(
              duration: WaveMotion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                widget.icon,
                key: ValueKey(widget.icon),
                size: widget.size,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
