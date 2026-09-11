import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../../data/music_api.dart';
import '../../data/track.dart';
import '../widgets/entrance.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/loadable.dart';
import '../widgets/section_header.dart';
import '../widgets/track_tile.dart';

/// Charts + mood browsing, the app's landing tab.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  Loadable<List<Track>> _charts = const Loading();
  Loadable<List<Track>> _moodTracks = const Loading();
  Mood _mood = kMoods.first;

  /// Incremented on every load so a slow response for an abandoned request
  /// cannot overwrite fresher results.
  int _chartsToken = 0;
  int _moodToken = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCharts();
      _loadMood(_mood);
    });
  }

  Future<void> _loadCharts() async {
    final token = ++_chartsToken;
    setState(() => _charts = const Loading());
    final music = WaveScope.of(context).music;
    try {
      final tracks = await music.charts(limit: 25);
      if (mounted && token == _chartsToken) {
        setState(() => _charts = Success(tracks));
      }
    } on MusicApiException catch (e) {
      if (mounted && token == _chartsToken) {
        setState(() => _charts = Failure(e.message));
      }
    } catch (_) {
      if (mounted && token == _chartsToken) {
        setState(() => _charts = const Failure('Could not load the charts.'));
      }
    }
  }

  Future<void> _loadMood(Mood mood) async {
    final token = ++_moodToken;
    setState(() {
      _mood = mood;
      _moodTracks = const Loading();
    });
    final music = WaveScope.of(context).music;
    try {
      final tracks = await music.byMood(mood, limit: 20);
      if (mounted && token == _moodToken) {
        setState(() => _moodTracks = Success(tracks));
      }
    } on MusicApiException catch (e) {
      if (mounted && token == _moodToken) {
        setState(() => _moodTracks = Failure(e.message));
      }
    } catch (_) {
      if (mounted && token == _moodToken) {
        setState(
          () => _moodTracks = const Failure('Could not load this mood.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final services = WaveScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        services.player,
        services.favorites,
        services.ambience,
      ]),
      builder: (context, _) {
        final palette = services.ambience.value;
        return CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await Future.wait([_loadCharts(), _loadMood(_mood)]);
              },
            ),
            SliverToBoxAdapter(child: _Greeting(palette: palette)),
            SliverToBoxAdapter(
              child: LoadableView<List<Track>>(
                state: _charts,
                accent: palette.primary,
                loadingHeight: 300,
                onRetry: _loadCharts,
                builder: (context, tracks) => FeaturedCarousel(
                  tracks: tracks.take(8).toList(),
                  palette: palette,
                  onPlay: (index) =>
                      services.player.playQueue(tracks, startIndex: index),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Moods',
                subtitle: 'Pick a feeling, not a genre',
              ),
            ),
            SliverToBoxAdapter(
              child: _MoodRow(selected: _mood, onSelect: _loadMood),
            ),
            SliverToBoxAdapter(
              child: LoadableView<List<Track>>(
                state: _moodTracks,
                accent: palette.primary,
                onRetry: () => _loadMood(_mood),
                builder: (context, tracks) => _MoodList(
                  tracks: tracks.take(6).toList(),
                  services: services,
                  palette: palette,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Top 25',
                subtitle: 'Most played right now',
              ),
            ),
            _ChartsSliver(
              state: _charts,
              services: services,
              palette: palette,
              onRetry: _loadCharts,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.palette});

  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 18 => 'Good afternoon',
      >= 18 && < 23 => 'Good evening',
      _ => 'Still awake',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting.toUpperCase(), style: WaveText.tiny),
          const SizedBox(height: 4),
          // The word "Wave" picks up the current artwork's colours.
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              colors: [palette.secondary, palette.primary, palette.tertiary],
            ).createShader(rect),
            child: const Text('Wave', style: WaveText.largeTitle),
          ),
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.selected, required this.onSelect});

  final Mood selected;
  final ValueChanged<Mood> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kMoods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mood = kMoods[index];
          return Entrance(
            index: index,
            offset: const Offset(24, 0),
            child: GlassChip(
              label: mood.title,
              icon: Icon(mood.icon),
              selected: mood.query == selected.query,
              onTap: () => onSelect(mood),
            ),
          );
        },
      ),
    );
  }
}

class _MoodList extends StatelessWidget {
  const _MoodList({
    required this.tracks,
    required this.services,
    required this.palette,
  });

  final List<Track> tracks;
  final WaveServices services;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.music_note_list,
        title: 'Nothing here yet',
        subtitle: 'Try another mood.',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (var i = 0; i < tracks.length; i++)
            Entrance(
              index: i,
              child: TrackTile(
                track: tracks[i],
                isCurrent: services.player.isCurrent(tracks[i]),
                isPlaying: services.player.isPlaying,
                liked: services.favorites.contains(tracks[i]),
                palette: palette,
                onTap: () => services.player.playQueue(tracks, startIndex: i),
                onLike: () => services.favorites.toggle(tracks[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartsSliver extends StatelessWidget {
  const _ChartsSliver({
    required this.state,
    required this.services,
    required this.palette,
    required this.onRetry,
  });

  final Loadable<List<Track>> state;
  final WaveServices services;
  final WavePalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case Loading():
        return const SliverToBoxAdapter(
          child: SizedBox(
            height: 160,
            child: Center(child: GlassProgressIndicator.circular(size: 26)),
          ),
        );
      case Failure(:final message):
        return SliverToBoxAdapter(
          child: LoadableView<List<Track>>(
            state: Failure(message),
            onRetry: onRetry,
            builder: (_, _) => const SizedBox.shrink(),
          ),
        );
      case Success(:final value):
        return SliverList.builder(
          itemCount: value.length,
          itemBuilder: (context, index) {
            final track = value[index];
            return Entrance(
              index: index,
              child: TrackTile(
                track: track,
                rank: index + 1,
                isCurrent: services.player.isCurrent(track),
                isPlaying: services.player.isPlaying,
                liked: services.favorites.contains(track),
                palette: palette,
                onTap: () =>
                    services.player.playQueue(value, startIndex: index),
                onLike: () => services.favorites.toggle(track),
              ),
            );
          },
        );
    }
  }
}
