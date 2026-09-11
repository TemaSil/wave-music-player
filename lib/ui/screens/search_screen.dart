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

/// Search results for the query typed into the tab bar's search capsule.
///
/// The field itself belongs to `GlassTabBar.searchable`, the way Apple Music
/// puts search in the bar rather than at the top of the page; this screen only
/// renders what the query returns.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.query,
    required this.contentPadding,
    required this.onSuggestion,
  });

  final String query;
  final double contentPadding;

  /// Fills the bar's field when a suggestion chip is tapped.
  final ValueChanged<String> onSuggestion;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;
  Loadable<List<Track>>? _results;
  String _searched = '';
  int _token = 0;

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) _schedule(widget.query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searched = '';
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
      _searched = query;
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
        setState(
          () =>
              _results = const Failure('Поиск не удался. Попробуйте ещё раз.'),
        );
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
        final palette = services.ambience.value;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).top + 12),
            ),
            if (_results == null)
              SliverToBoxAdapter(
                child: _Suggestions(onTap: widget.onSuggestion),
              )
            else
              SliverToBoxAdapter(
                child: LoadableView<List<Track>>(
                  state: _results!,
                  accent: palette.primary,
                  onRetry: () => _search(_searched),
                  builder: (context, tracks) => tracks.isEmpty
                      ? EmptyState(
                          icon: CupertinoIcons.search,
                          title: 'Ничего не найдено по «$_searched»',
                          subtitle: 'Проверьте написание или смените каталог в настройках.',
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
            SliverToBoxAdapter(child: SizedBox(height: widget.contentPadding)),
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
          Text('ПОПРОБУЙТЕ', style: WaveText.tiny),
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
