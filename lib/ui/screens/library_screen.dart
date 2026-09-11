import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/loadable.dart';
import '../widgets/section_header.dart';
import '../widgets/track_tile.dart';

/// Locally saved favourites.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final services = WaveScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        services.player,
        services.favorites,
        services.ambience,
      ]),
      builder: (context, _) {
        final palette = services.ambience.value;
        final tracks = services.favorites.tracks;
        final playable = tracks.where((t) => t.isPlayable).toList();

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Library', style: WaveText.largeTitle),
                    const SizedBox(height: 4),
                    Text(
                      tracks.isEmpty
                          ? 'Saved on this device'
                          : '${tracks.length} saved · ${playable.length} playable',
                      style: WaveText.caption,
                    ),
                  ],
                ),
              ),
            ),
            if (tracks.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: CupertinoIcons.heart,
                  title: 'Nothing saved yet',
                  subtitle: 'Tap the heart on any track to keep it here.',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Liked songs',
                  subtitle: 'Newest first',
                  trailing: playable.isEmpty
                      ? null
                      : GlassButton(
                          icon: const Icon(CupertinoIcons.shuffle),
                          onTap: () async {
                            await services.player.playQueue(playable);
                            if (!services.player.shuffle) {
                              await services.player.toggleShuffle();
                            }
                          },
                          label: 'Shuffle liked songs',
                          width: 44,
                          height: 44,
                          iconSize: 18,
                          glowColor: palette.primary,
                        ),
                ),
              ),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return Entrance(
                    index: index,
                    child: TrackTile(
                      track: track,
                      isCurrent: services.player.isCurrent(track),
                      isPlaying: services.player.isPlaying,
                      liked: true,
                      palette: palette,
                      onTap: () {
                        final start = playable.indexWhere(
                          (t) => t.uid == track.uid,
                        );
                        services.player.playQueue(
                          playable,
                          startIndex: start < 0 ? 0 : start,
                        );
                      },
                      onLike: () => services.favorites.toggle(track),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        );
      },
    );
  }
}
