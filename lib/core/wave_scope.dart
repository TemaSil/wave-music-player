import 'package:flutter/widgets.dart';

import '../audio/player_service.dart';
import '../data/favorites_repository.dart';
import '../data/music_api.dart';
import '../data/palette_service.dart';
import 'appearance.dart';
import 'wave_theme.dart';

/// Tracks the palette of whatever is currently playing.
///
/// Palette extraction is async, so this sits between the player and every
/// ambient surface: widgets listen to one notifier instead of each kicking off
/// their own extraction.
class AmbienceNotifier extends ValueNotifier<WavePalette> {
  AmbienceNotifier(this._player, this._palettes, this._appearance)
    : super(WavePalette.appleMusic) {
    _player.addListener(_onPlayerChanged);
    _appearance.addListener(_onAppearanceChanged);
    _onAppearanceChanged();
  }

  final PlayerService _player;
  final PaletteService _palettes;
  final AppearanceController _appearance;

  String? _resolvedFor;

  WavePalette _artwork = WavePalette.fallback;

  /// The current track's own colours, regardless of skin.
  ///
  /// Apple Music keeps its app chrome black but still tints Now Playing from
  /// the artwork, so that screen reads this instead of [value].
  WavePalette get artwork => _artwork;

  void _publish() {
    value = _appearance.usesLiveColour ? _artwork : WavePalette.appleMusic;
  }

  void _onAppearanceChanged() {
    _publish();
    // A skin change can arrive before any track has been analysed.
    if (_appearance.usesLiveColour) _onPlayerChanged(force: true);
  }

  void _onPlayerChanged({bool force = false}) {
    final track = _player.current;
    if (track == null) return;
    if (!force && track.uid == _resolvedFor) return;
    _resolvedFor = track.uid;

    final cached = _palettes.cached(track);
    if (cached != null) {
      _artwork = cached;
      _publish();
      return;
    }
    _palettes.of(track).then((palette) {
      // Guard against a late result for a track we have already moved past.
      if (_resolvedFor != track.uid) return;
      _artwork = palette;
      _publish();
    });
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _appearance.removeListener(_onAppearanceChanged);
    super.dispose();
  }
}

/// Bundles the app's long-lived services and hands them to the widget tree.
class WaveServices {
  WaveServices()
    : player = PlayerService(),
      music = MusicRepository(),
      favorites = FavoritesRepository(),
      palettes = PaletteService(),
      appearance = AppearanceController() {
    ambience = AmbienceNotifier(player, palettes, appearance);
    // Settings own the switch; the player owns the behaviour.
    appearance.addListener(_syncPlaybackSettings);
    _syncPlaybackSettings();
  }

  void _syncPlaybackSettings() => player.setAutomix(appearance.automix);

  final PlayerService player;
  final MusicRepository music;
  final FavoritesRepository favorites;
  final PaletteService palettes;
  final AppearanceController appearance;
  late final AmbienceNotifier ambience;

  void dispose() {
    appearance.removeListener(_syncPlaybackSettings);
    ambience.dispose();
    player.dispose();
    favorites.dispose();
    appearance.dispose();
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
