import 'track.dart';
import 'music_api.dart';

/// A self-contained catalogue backed by bundled assets.
///
/// Enabled with `--dart-define=WAVE_DEMO=true`. It exists so the app can be
/// run, screenshotted and smoke-tested with no network and no API at all —
/// the screenshots in the README are captured from this mode. Nothing here is
/// used by a normal build.
class DemoSource implements MusicSource {
  const DemoSource();

  static const _preview = 'assets/demo/preview.wav';

  static const _catalogue = <Track>[
    Track(
      id: 'demo-1',
      title: 'Aurora Drift',
      artist: 'Nova Fields',
      album: 'Long Exposure',
      artworkUrl: 'assets/demo/aurora.png',
      previewUrl: _preview,
      duration: Duration(minutes: 3, seconds: 42),
      genre: 'Ambient',
      releaseYear: 2025,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-2',
      title: 'Ember Coast',
      artist: 'Halcyon Six',
      album: 'Warm Static',
      artworkUrl: 'assets/demo/ember.png',
      previewUrl: _preview,
      duration: Duration(minutes: 4, seconds: 8),
      genre: 'Electronic',
      releaseYear: 2024,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-3',
      title: 'Lagoon Signal',
      artist: 'Tidebreak',
      album: 'Shallow Water',
      artworkUrl: 'assets/demo/lagoon.png',
      previewUrl: _preview,
      duration: Duration(minutes: 3, seconds: 15),
      genre: 'Downtempo',
      releaseYear: 2025,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-4',
      title: 'Violet Hour',
      artist: 'Ana Perrin',
      album: 'Slow Dissolve',
      artworkUrl: 'assets/demo/violet.png',
      previewUrl: _preview,
      duration: Duration(minutes: 4, seconds: 31),
      genre: 'Dream Pop',
      releaseYear: 2023,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-5',
      title: 'Dusk Transit',
      artist: 'Kite Museum',
      album: 'Night Bus',
      artworkUrl: 'assets/demo/dusk.png',
      previewUrl: _preview,
      duration: Duration(minutes: 2, seconds: 58),
      genre: 'Indie',
      releaseYear: 2025,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-6',
      title: 'Solar Bloom',
      artist: 'Ravi Okonjo',
      album: 'Golden Hour',
      artworkUrl: 'assets/demo/solar.png',
      previewUrl: _preview,
      duration: Duration(minutes: 3, seconds: 50),
      genre: 'House',
      releaseYear: 2024,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-7',
      title: 'Monochrome',
      artist: 'Pale Atlas',
      album: 'Grey Room',
      artworkUrl: 'assets/demo/mono.png',
      previewUrl: _preview,
      duration: Duration(minutes: 5, seconds: 12),
      genre: 'Post-rock',
      releaseYear: 2022,
      source: MusicSourceId.demo,
    ),
    Track(
      id: 'demo-8',
      title: 'Tidewater',
      artist: 'Sable Coast',
      album: 'Blue Interval',
      artworkUrl: 'assets/demo/tide.png',
      previewUrl: _preview,
      duration: Duration(minutes: 3, seconds: 27),
      genre: 'Chillwave',
      releaseYear: 2025,
      source: MusicSourceId.demo,
    ),
  ];

  @override
  MusicSourceId get id => MusicSourceId.demo;

  @override
  Future<List<Track>> charts({int limit = 25}) async {
    await _latency();
    return _catalogue.take(limit).toList();
  }

  @override
  Future<List<Track>> search(String query, {int limit = 50}) async {
    await _latency();
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return _catalogue
        .where(
          (t) =>
              t.title.toLowerCase().contains(needle) ||
              t.artist.toLowerCase().contains(needle) ||
              t.album.toLowerCase().contains(needle) ||
              t.genre.toLowerCase().contains(needle),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<Track>> byMood(String mood, {int limit = 40}) async {
    await _latency();
    // Rotate the fixture list per mood so each chip shows a different set.
    final offset = mood.hashCode.abs() % _catalogue.length;
    return [
      ..._catalogue.skip(offset),
      ..._catalogue.take(offset),
    ].take(limit).toList();
  }

  /// A touch of delay so loading states are still exercised in demo mode.
  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 350));
}
