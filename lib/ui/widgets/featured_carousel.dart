import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_theme.dart';
import '../../data/track.dart';
import 'artwork_image.dart';
import 'press_scale.dart';

/// Swipeable hero cards for the top of Discover.
///
/// Cards scale and fade with their distance from the centre, and the artwork
/// inside slides against the swipe to give the stack some depth.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({
    super.key,
    required this.tracks,
    required this.palette,
    required this.onPlay,
    this.height = 300,
  });

  final List<Track> tracks;
  final WavePalette palette;

  /// Called with the index of the tapped card.
  final ValueChanged<int> onPlay;
  final double height;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  static const _viewportFraction = 0.74;

  late final PageController _controller = PageController(
    viewportFraction: _viewportFraction,
  );
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // page is null until the first layout pass.
      final page = _controller.page;
      if (page != null && page != _page) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _controller,
        padEnds: true,
        itemCount: widget.tracks.length,
        itemBuilder: (context, index) {
          final delta = (index - _page);
          final distance = delta.abs().clamp(0.0, 1.0);
          return Transform.scale(
            scale: 1 - distance * 0.12,
            child: Opacity(
              opacity: 1 - distance * 0.35,
              child: _FeaturedCard(
                track: widget.tracks[index],
                palette: widget.palette,
                // Counter-slide the artwork for parallax against the swipe.
                parallax: delta.clamp(-1.0, 1.0),
                onTap: () => widget.onPlay(index),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.track,
    required this.palette,
    required this.parallax,
    required this.onTap,
  });

  final Track track;
  final WavePalette palette;
  final double parallax;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.28),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Over-sized so the parallax shift never exposes an edge.
                OverflowBox(
                  maxWidth: double.infinity,
                  child: Transform.translate(
                    offset: Offset(parallax * 34, 0),
                    child: Transform.scale(
                      scale: 1.18,
                      child: ArtworkImage(url: track.artworkUrl, iconSize: 40),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0x00000000),
                        const Color(0xFF000000).withValues(alpha: 0.35),
                        const Color(0xFF000000).withValues(alpha: 0.85),
                      ],
                      stops: const [0.35, 0.62, 1.0],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WaveText.title.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WaveText.caption.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassButton(
                        icon: const Icon(CupertinoIcons.play_fill),
                        onTap: onTap,
                        label: 'Play ${track.title}',
                        width: 46,
                        height: 46,
                        iconSize: 18,
                        glowColor: palette.primary,
                        settings: LiquidGlassSettings(
                          blur: 10,
                          thickness: 24,
                          glassColor: palette.primary.withValues(alpha: 0.24),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
