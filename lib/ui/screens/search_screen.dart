import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../../data/music_api.dart';
import '../../data/track.dart';
import '../widgets/entrance.dart';
import '../widgets/loadable.dart';
import '../widgets/track_tile.dart';

/// Free-text search across the active catalogue, with a source switcher.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// Shown before the first query, so the empty screen still offers a way in.
const _kSuggestions = [
  'Fred again',
  'Tame Impala',
  'Kendrick Lamar',
  'Bicep',
  'Sade',
  'Rosalía',
  'Jungle',
  'Khruangbin',
];

/// The live suggestions are real artists, which the bundled demo catalogue has
/// never heard of; these match its fixtures instead.
const _kDemoSuggestions = [
  'Coast',
  'Nova Fields',
  'Chillwave',
  'Ambient',
  'Kite Museum',
  'Pale Atlas',
];

List<String> get _suggestions => kDemoMode ? _kDemoSuggestions : _kSuggestions;

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;
  Loadable<List<Track>>? _results;
  String _query = '';
  int _token = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _results = null;
      });
      return;
    }
    // Typing fires per keystroke; only the pause at the end is worth a request.
    _debounce = Timer(const Duration(milliseconds: 420), () => _search(value));
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    final token = ++_token;
    setState(() {
      _query = query;
      _results = const Loading();
    });

    final music = WaveScope.of(context).music;
    try {
      final tracks = await music.search(query);
      if (mounted && token == _token) {
        setState(() => _results = Success(tracks));
      }
    } on MusicApiException catch (e) {
      if (mounted && token == _token) {
        setState(() => _results = Failure(e.message));
      }
    } catch (_) {
      if (mounted && token == _token) {
        setState(() => _results = const Failure('Search failed. Try again.'));
      }
    }
  }

  void _runSuggestion(String value) {
    _field.text = value;
    _search(value);
  }

  void _switchSource(MusicSourceId id) {
    final music = WaveScope.of(context).music;
    if (music.activeId == id) return;
    setState(() => music.activeId = id);
    if (_query.isNotEmpty) _search(_query);
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Search', style: WaveText.largeTitle),
                    const SizedBox(height: 14),
                    GlassSearchBar(
                      controller: _field,
                      placeholder: 'Songs, artists, albums…',
                      onChanged: _onChanged,
                      onSubmitted: _search,
                      showsCancelButton: true,
                      onCancel: () {
                        _field.clear();
                        _onChanged('');
                      },
                    ),
                    // Demo mode has a single bundled catalogue, so there is
                    // nothing to switch between.
                    if (!kDemoMode) ...[
                      const SizedBox(height: 12),
                      GlassSegmentedControl(
                        segments: const [
                          GlassSegment(label: 'Apple / iTunes'),
                          GlassSegment(label: 'Deezer'),
                        ],
                        selectedIndex:
                            services.music.activeId == MusicSourceId.itunes
                            ? 0
                            : 1,
                        onSegmentSelected: (index) => _switchSource(
                          index == 0
                              ? MusicSourceId.itunes
                              : MusicSourceId.deezer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_results == null)
              SliverToBoxAdapter(child: _Suggestions(onTap: _runSuggestion))
            else
              SliverToBoxAdapter(
                child: LoadableView<List<Track>>(
                  state: _results!,
                  accent: palette.primary,
                  onRetry: () => _search(_query),
                  builder: (context, tracks) => tracks.isEmpty
                      ? EmptyState(
                          icon: CupertinoIcons.search,
                          title: 'No results for "$_query"',
                          subtitle:
                              'Check the spelling, or try the other catalogue.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < tracks.length; i++)
                              Entrance(
                                index: i,
                                child: TrackTile(
                                  track: tracks[i],
                                  isCurrent: services.player.isCurrent(
                                    tracks[i],
                                  ),
                                  isPlaying: services.player.isPlaying,
                                  liked: services.favorites.contains(tracks[i]),
                                  palette: palette,
                                  onTap: () => services.player.playQueue(
                                    tracks,
                                    startIndex: i,
                                  ),
                                  onLike: () =>
                                      services.favorites.toggle(tracks[i]),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        );
      },
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRY SOMETHING', style: WaveText.tiny),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _suggestions.length; i++)
                Entrance(
                  index: i,
                  offset: const Offset(0, 14),
                  child: GlassChip(
                    label: _suggestions[i],
                    onTap: () => onTap(_suggestions[i]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
