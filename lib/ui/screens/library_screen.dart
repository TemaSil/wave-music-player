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
  const LibraryScreen({
    super.key,
    required this.scrollController,
    required this.contentPadding,
  });

  final ScrollController scrollController;

  /// Space the floating tab bar and play pill need at the bottom of the list.
  final double contentPadding;

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
            // The shell paints the large title; this only clears it.
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).top + 52),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Text(
                  tracks.isEmpty
                      ? 'Сохранено на этом устройстве'
                      : '${tracks.length} сохранено · ${playable.length} с превью',
                  style: WaveText.caption,
                ),
              ),
            ),
            if (tracks.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: CupertinoIcons.heart,
                  title: 'Пока пусто',
                  subtitle:
                      'Нажмите сердечко на любом треке — он окажется здесь.',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Любимые треки',
                  subtitle: 'Сначала новые',
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
            SliverToBoxAdapter(child: SizedBox(height: contentPadding)),
          ],
        );
      },
    );
  }
}
