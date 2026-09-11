import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../../data/music_api.dart';
import '../../data/track.dart';
import '../widgets/artwork_image.dart';
import '../widgets/entrance.dart';
import '../widgets/loadable.dart';
import '../widgets/track_tile.dart';

/// What a [CollectionScreen] is showing.
enum CollectionKind { album, artist }

/// Pushes the album the track belongs to.
void openAlbum(BuildContext context, Track track) => Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (_) => CollectionScreen(seed: track, kind: CollectionKind.album),
  ),
);

/// Pushes the track's artist.
void openArtist(BuildContext context, Track track) =>
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            CollectionScreen(seed: track, kind: CollectionKind.artist),
      ),
    );

/// An album or an artist, built from whichever track led here.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.seed, required this.kind});

  /// The track the user came from; supplies the ids and the artwork.
  final Track seed;
  final CollectionKind kind;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  Loadable<List<Track>> _tracks = const Loading();
  int _token = 0;

  String get _title => switch (widget.kind) {
    CollectionKind.album =>
      widget.seed.album.isEmpty ? widget.seed.title : widget.seed.album,
    CollectionKind.artist => widget.seed.artist,
  };

  String get _subtitle => switch (widget.kind) {
    CollectionKind.album => widget.seed.artist,
    CollectionKind.artist => 'Популярные треки',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() => _tracks = const Loading());
    final music = WaveScope.of(context).music;
    try {
      final result = switch (widget.kind) {
        CollectionKind.album => await music.album(widget.seed),
        CollectionKind.artist => await music.artist(widget.seed),
      };
      if (mounted && token == _token) setState(() => _tracks = Success(result));
    } on MusicApiException catch (e) {
      if (mounted && token == _token) {
        setState(() => _tracks = Failure(e.message));
      }
    } catch (_) {
      if (mounted && token == _token) {
        setState(() => _tracks = const Failure('Не удалось загрузить.'));
      }
    }
  }

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
        final palette = services.appearance.usesLiveColour
            ? services.ambience.value
            : WavePalette.appleMusic;

        return GlassScaffold(
          backgroundColor: WaveColors.appleBackground,
          statusBarStyle: GlassStatusBarStyle.light,
          background: const ColoredBox(color: WaveColors.appleBackground),
          settings: appleMusicGlass(),
          appBar: GlassAppBar.pinned(
            title: Text(_title, style: WaveText.section),
            onBack: () => Navigator.of(context).maybePop(),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  seed: widget.seed,
                  kind: widget.kind,
                  title: _title,
                  subtitle: _subtitle,
                  palette: palette,
                  tracks: _tracks,
                  services: services,
                ),
              ),
              switch (_tracks) {
                Loading<List<Track>>() => const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: Center(
                      child: GlassProgressIndicator.circular(size: 26),
                    ),
                  ),
                ),
                Failure<List<Track>>(:final message) => SliverToBoxAdapter(
                  child: LoadableView<List<Track>>(
                    state: Failure(message),
                    accent: palette.primary,
                    onRetry: _load,
                    builder: (_, _) => const SizedBox.shrink(),
                  ),
                ),
                Success<List<Track>>(:final value) =>
                  value.isEmpty
                      ? const SliverToBoxAdapter(
                          child: EmptyState(
                            icon: CupertinoIcons.music_note_list,
                            title: 'Ничего не нашлось',
                            subtitle:
                                'Каталог не отдал треки для этой страницы.',
                          ),
                        )
                      : SliverList.builder(
                          itemCount: value.length,
                          itemBuilder: (context, index) => Entrance(
                            index: index,
                            child: TrackTile(
                              track: value[index],
                              // On an album the running order is the useful
                              // number; for an artist it would be meaningless.
                              rank: widget.kind == CollectionKind.album
                                  ? index + 1
                                  : null,
                              isCurrent: services.player.isCurrent(
                                value[index],
                              ),
                              isPlaying: services.player.isPlaying,
                              liked: services.favorites.contains(value[index]),
                              palette: palette,
                              onTap: () => services.player.playQueue(
                                value,
                                startIndex: index,
                              ),
                              onLike: () =>
                                  services.favorites.toggle(value[index]),
                            ),
                          ),
                        ),
              },
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.seed,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.tracks,
    required this.services,
  });

  final Track seed;
  final CollectionKind kind;
  final String title;
  final String subtitle;
  final WavePalette palette;
  final Loadable<List<Track>> tracks;
  final WaveServices services;

  @override
  Widget build(BuildContext context) {
    final playable = switch (tracks) {
      Success<List<Track>>(:final value) =>
        value.where((t) => t.isPlayable).toList(),
      _ => const <Track>[],
    };
    final round = kind == CollectionKind.artist;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 56,
        24,
        18,
      ),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.30),
                  blurRadius: 50,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipPath(
              clipper: null,
              child: round
                  ? ClipOval(
                      child: SizedBox.square(
                        dimension: 176,
                        child: ArtworkImage(url: seed.artworkUrl, iconSize: 44),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.square(
                        dimension: 196,
                        child: ArtworkImage(url: seed.artworkUrl, iconSize: 44),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: WaveText.title.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WaveText.caption.copyWith(
              fontSize: 15,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeaderButton(
                  icon: CupertinoIcons.play_fill,
                  label: 'Слушать',
                  accent: palette.primary,
                  onTap: playable.isEmpty
                      ? null
                      : () => services.player.playQueue(playable),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderButton(
                  icon: CupertinoIcons.shuffle,
                  label: 'Вперемешку',
                  accent: palette.primary,
                  onTap: playable.isEmpty
                      ? null
                      : () async {
                          await services.player.playQueue(playable);
                          if (!services.player.shuffle) {
                            await services.player.toggleShuffle();
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: accent.withValues(alpha: enabled ? 0.18 : 0.07),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: accent.withValues(alpha: enabled ? 1 : 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: WaveText.body.copyWith(
                fontSize: 15,
                color: accent.withValues(alpha: enabled ? 1 : 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
