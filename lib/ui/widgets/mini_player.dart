import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../audio/player_service.dart';
import '../../core/wave_theme.dart';
import '../screens/now_playing_screen.dart';
import 'artwork_image.dart';
import 'marquee_text.dart';
import 'play_pause_button.dart';

/// The persistent play pill, mounted as the tab bar's bottom accessory — the
/// same slot iOS 26 gives `tabViewBottomAccessory`.
///
/// Tapping it expands into the full Now Playing screen; the artwork flies
/// across via [kNowPlayingHeroTag].
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.player, required this.palette});

  final PlayerService player;
  final WavePalette palette;

  static const height = 62.0;

  @override
  Widget build(BuildContext context) {
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

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
        child: Padding(
          // Matches the inset GlassTabBar.bottom gives its own pill, so the
          // accessory and the bar share an edge.
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: height,
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
                      padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
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
                                    style: WaveText.caption.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          PlayPauseButton(
                            isPlaying: player.isPlaying,
                            isBusy: player.isBusy,
                            onTap: player.toggle,
                            size: 38,
                            accent: palette.primary,
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: player.next,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Icon(
                                CupertinoIcons.forward_end_fill,
                                size: 18,
                                color: WaveColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _ProgressHairline(
                    progress: player.progress,
                    palette: palette,
                  ),
                ],
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
