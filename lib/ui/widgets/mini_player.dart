import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../audio/player_service.dart';
import '../../core/wave_theme.dart';
import '../screens/now_playing_screen.dart';
import 'artwork_image.dart';
import 'marquee_text.dart';

/// The persistent play pill, mounted as the tab bar's bottom accessory — the
/// same slot iOS 26 gives `tabViewBottomAccessory`.
///
/// It reads [GlassTabBarAccessoryPlacementScope] and swaps layout as the bar
/// minimizes: a full row above the bar when expanded, a compact strip that
/// fits inside the bar's own footprint when the bar has shrunk. The bar
/// positions the accessory but paints no surface behind it, so the expanded
/// form brings its own glass and the inline form deliberately does not — it is
/// already sitting on the bar's glass.
///
/// Tapping it expands into the full Now Playing screen; the artwork flies
/// across via [kNowPlayingHeroTag].
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.player, required this.palette});

  final PlayerService player;
  final WavePalette palette;

  /// Height of the expanded form, which is what the scaffold insets for.
  static const height = 62.0;

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(NowPlayingRoute()),
        // A downward fling dismisses nothing here, but an upward one is the
        // natural gesture for "open the full player".
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -200) {
            Navigator.of(context).push(NowPlayingRoute());
          }
        },
        child: AnimatedSwitcher(
          duration: WaveMotion.medium,
          switchInCurve: WaveMotion.emphasized,
          child: inline
              ? _InlineRow(
                  key: const ValueKey('inline'),
                  player: player,
                  palette: palette,
                )
              : _ExpandedPill(
                  key: const ValueKey('expanded'),
                  player: player,
                  palette: palette,
                ),
        ),
      ),
    );
  }
}

/// Full-width pill that floats above the tab bar, on its own glass.
class _ExpandedPill extends StatelessWidget {
  const _ExpandedPill({super.key, required this.player, required this.palette});

  final PlayerService player;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    final track = player.current!;
    return Padding(
      // Matches the inset GlassTabBar gives its own pill, so the accessory and
      // the bar share an edge.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: MiniPlayer.height,
        child: GlassContainer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 26),
          settings: LiquidGlassSettings(
            blur: 14,
            thickness: 22,
            glassColor: palette.primary.withValues(alpha: 0.16),
            lightIntensity: 0.7,
            saturation: 1.6,
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                  child: Row(
                    children: [
                      Hero(
                        tag: kNowPlayingHeroTag,
                        child: ClipRSuperellipse(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.square(
                            dimension: 42,
                            child: ArtworkImage(
                              url: track.thumbnailUrl,
                              iconSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 18,
                              child: MarqueeText(
                                track.title,
                                style: WaveText.body.copyWith(fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 1),
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
                      const SizedBox(width: 4),
                      _TransportGlyph(
                        icon: player.isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        label: player.isPlaying ? 'Pause' : 'Play',
                        onTap: player.toggle,
                        size: 22,
                      ),
                      _TransportGlyph(
                        icon: CupertinoIcons.forward_end_fill,
                        label: 'Next track',
                        onTap: player.next,
                      ),
                    ],
                  ),
                ),
              ),
              _ProgressHairline(progress: player.progress, palette: palette),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact strip for when the bar has minimized and the accessory sits inside
/// the bar's own glass — so this form paints no surface of its own.
class _InlineRow extends StatelessWidget {
  const _InlineRow({super.key, required this.player, required this.palette});

  final PlayerService player;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    final track = player.current!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Hero(
            tag: kNowPlayingHeroTag,
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox.square(
                dimension: 30,
                child: ArtworkImage(url: track.thumbnailUrl, iconSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 18,
              child: MarqueeText(
                track.title,
                style: WaveText.body.copyWith(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _TransportGlyph(
            icon: player.isPlaying
                ? CupertinoIcons.pause_fill
                : CupertinoIcons.play_fill,
            label: player.isPlaying ? 'Pause' : 'Play',
            onTap: player.toggle,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// A bare glyph, not a [GlassButton].
///
/// The package's own guidance is that glass is a platter rather than a
/// wrapper: interactive glass controls are not meant to sit inside another
/// glass surface, and doing so is what gave the old pill its muddy,
/// double-refracted buttons.
class _TransportGlyph extends StatefulWidget {
  const _TransportGlyph({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 20,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  State<_TransportGlyph> createState() => _TransportGlyphState();
}

class _TransportGlyphState extends State<_TransportGlyph> {
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
          scale: _pressed ? 0.86 : 1.0,
          duration: WaveMotion.fast,
          curve: WaveMotion.emphasized,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                color: WaveColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 2px progress line hugging the bottom of the pill.
class _ProgressHairline extends StatelessWidget {
  const _ProgressHairline({required this.progress, required this.palette});

  final double progress;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 2.5,
          child: Stack(
            children: [
              const ColoredBox(
                color: WaveColors.hairline,
                child: SizedBox.expand(),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.secondary, palette.primary],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
