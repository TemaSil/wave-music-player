import 'package:flutter/widgets.dart';

import '../audio/player_service.dart';
import '../data/favorites_repository.dart';
import '../data/music_api.dart';
import '../data/palette_service.dart';
import 'wave_theme.dart';

/// Tracks the palette of whatever is currently playing.
///
/// Palette extraction is async, so this sits between the player and every
/// ambient surface: widgets listen to one notifier instead of each kicking off
/// their own extraction.
class AmbienceNotifier extends ValueNotifier<WavePalette> {
  AmbienceNotifier(this._player, this._palettes) : super(WavePalette.fallback) {
    _player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  final PlayerService _player;
  final PaletteService _palettes;
  String? _resolvedFor;

  void _onPlayerChanged() {
    final track = _player.current;
    if (track == null || track.uid == _resolvedFor) return;
    _resolvedFor = track.uid;

    final cached = _palettes.cached(track);
    if (cached != null) {
      value = cached;
      return;
    }
    _palettes.of(track).then((palette) {
      // Guard against a late result for a track we have already moved past.
      if (_resolvedFor == track.uid) value = palette;
    });
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    super.dispose();
  }
}

/// Bundles the app's long-lived services and hands them to the widget tree.
class WaveServices {
  WaveServices()
    : player = PlayerService(),
      music = MusicRepository(),
      favorites = FavoritesRepository(),
      palettes = PaletteService() {
    ambience = AmbienceNotifier(player, palettes);
  }

  final PlayerService player;
  final MusicRepository music;
  final FavoritesRepository favorites;
  final PaletteService palettes;
  late final AmbienceNotifier ambience;

  void dispose() {
    ambience.dispose();
    player.dispose();
    favorites.dispose();
  }
}

class WaveScope extends InheritedWidget {
  const WaveScope({required this.services, required super.child, super.key});

  final WaveServices services;

  static WaveServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WaveScope>();
    assert(scope != null, 'No WaveScope found above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(WaveScope oldWidget) =>
      oldWidget.services != services;
}
