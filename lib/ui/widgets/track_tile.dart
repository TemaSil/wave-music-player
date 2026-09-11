import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_theme.dart';
import '../../data/track.dart';
import 'artwork_image.dart';
import 'equalizer_bars.dart';
import 'like_button.dart';
import 'press_scale.dart';

/// One row in every list in the app.
///
/// The currently playing row lifts onto its own glass slab and swaps its
/// duration for a live equaliser, so the queue position is readable at a glance
/// while scrolling.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.liked,
    required this.palette,
    required this.onTap,
    required this.onLike,
    this.rank,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool liked;
  final WavePalette palette;
  final VoidCallback onTap;
  final VoidCallback onLike;

  /// 1-based chart position, shown instead of nothing on the charts list.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final accent = palette.primary;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: WaveText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? accent : WaveColors.textTertiary,
                ),
              ),
            ),
          if (rank != null) const SizedBox(width: 8),
          _buildArtwork(accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WaveText.body.copyWith(
                    color: isCurrent ? accent : WaveColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.album.isEmpty
                      ? track.artist
                      : '${track.artist} · ${track.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WaveText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildTrailing(accent),
          LikeButton(liked: liked, onTap: onLike, size: 18),
        ],
      ),
    );

    // AnimatedSwitcher would rebuild the row; a cross-fading slab keeps the
    // layout identical and only the background changes.
    final content = AnimatedContainer(
      duration: WaveMotion.medium,
      curve: WaveMotion.emphasized,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: isCurrent
          ? GlassContainer(
              shape: const LiquidRoundedSuperellipse(borderRadius: 18),
              settings: LiquidGlassSettings(
                blur: 8,
                thickness: 14,
                glassColor: accent.withValues(alpha: 0.14),
                lightIntensity: 0.6,
              ),
              child: row,
            )
          : row,
    );

    return PressScale(onTap: onTap, child: content);
  }

  Widget _buildArtwork(Color accent) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: WaveMotion.medium,
          curve: WaveMotion.emphasized,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isCurrent
                    ? accent.withValues(alpha: 0.45)
                    : const Color(0x00000000),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(14),
            child: ArtworkImage(url: track.thumbnailUrl),
          ),
        ),
        // Scrim + equaliser over the thumbnail while this row is the one playing.
        AnimatedOpacity(
          opacity: isCurrent ? 1 : 0,
          duration: WaveMotion.fast,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF000000).withValues(alpha: 0.45),
            ),
            child: Center(
              child: EqualizerBars(
                color: const Color(0xFFFFFFFF),
                animating: isCurrent && isPlaying,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing(Color accent) {
    if (!track.isPlayable) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          CupertinoIcons.nosign,
          size: 15,
          color: WaveColors.textTertiary.withValues(alpha: 0.7),
        ),
      );
    }
    if (track.duration == Duration.zero) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        formatDuration(track.duration),
        style: WaveText.tiny.copyWith(
          color: isCurrent ? accent : WaveColors.textTertiary,
        ),
      ),
    );
  }
}
