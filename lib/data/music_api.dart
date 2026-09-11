import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import 'demo_source.dart';
import 'track.dart';

/// Raised when a catalogue request fails in a way worth showing to the user.
class MusicApiException implements Exception {
  MusicApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A read-only public music catalogue.
///
/// Both implementations below are key-free public APIs, so the app needs no
/// signup, no secrets and no build-time configuration.
abstract interface class MusicSource {
  MusicSourceId get id;

  /// Free-text search across songs.
  Future<List<Track>> search(String query, {int limit});

  /// The catalogue's current most-played songs.
  Future<List<Track>> charts({int limit});

  /// Songs matching a mood/genre keyword.
  Future<List<Track>> byMood(String mood, {int limit});

  /// Every track on the album the given track belongs to, in running order.
  Future<List<Track>> album(Track track, {int limit});

  /// Top tracks by the given track's artist.
  Future<List<Track>> artist(Track track, {int limit});
}

/// Apple's iTunes Search API plus the Apple Marketing Tools RSS charts.
///
/// No API key, no rate-limit signup; ~20 requests/minute per IP is the
/// documented soft limit, which is well above what this UI generates.
class ItunesSource implements MusicSource {
  ItunesSource({http.Client? client, this.storefront = 'us'})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Two-letter storefront, e.g. `us`, `gb`, `de`. Affects catalogue and charts.
  final String storefront;

  @override
  MusicSourceId get id => MusicSourceId.itunes;

  @override
  Future<List<Track>> search(String query, {int limit = 50}) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'entity': 'song',
      'media': 'music',
      'limit': '$limit',
      'country': storefront,
    });
    return _songs(await _getJson(uri));
  }

  @override
  Future<List<Track>> byMood(String mood, {int limit = 40}) =>
      search(mood, limit: limit);

  @override
  Future<List<Track>> charts({int limit = 25}) async {
    // The RSS feed gives us the ranking but no preview stream, so we take the
    // ids it returns and resolve them through /lookup in a single follow-up
    // request. Chart order is preserved by re-indexing the lookup results.
    final feedUri = Uri.https(
      'rss.marketingtools.apple.com',
      '/api/v2/$storefront/music/most-played/$limit/songs.json',
    );
    final feed = await _getJson(feedUri);
    final results =
        ((feed['feed'] as Map<String, dynamic>?)?['results'] as List?) ??
        const [];
    final ids = results
        .whereType<Map<String, dynamic>>()
        .map((e) => e['id'])
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    final lookupUri = Uri.https('itunes.apple.com', '/lookup', {
      'id': ids.join(','),
      'entity': 'song',
      'country': storefront,
    });
    final tracks = _songs(await _getJson(lookupUri));
    final byId = {for (final t in tracks) t.id: t};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<List<Track>> album(Track track, {int limit = 40}) async {
    final id = track.collectionId;
    if (id == null) {
      return search('${track.artist} ${track.album}', limit: limit);
    }
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'id': id,
      'entity': 'song',
      'limit': '$limit',
      'country': storefront,
    });
    // The first result of an album lookup is the album itself, not a track;
    // _songs drops it because its wrapperType is 'collection'.
    return _songs(await _getJson(uri));
  }

  @override
  Future<List<Track>> artist(Track track, {int limit = 40}) async {
    final id = track.artistId;
    if (id == null) return search(track.artist, limit: limit);
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'id': id,
      'entity': 'song',
      'limit': '$limit',
      'country': storefront,
    });
    return _songs(await _getJson(uri));
  }

  List<Track> _songs(Map<String, dynamic> json) {
    final results = (json['results'] as List?) ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((e) => e['wrapperType'] == 'track' || e['kind'] == 'song')
        .map(Track.fromItunes)
        .where((t) => t.artworkUrl.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) => _requestJson(_client, uri);
}

/// Deezer's public API — an alternative catalogue with the same 30s previews.
///
/// Kept as a second source so the app degrades gracefully when one catalogue
/// is unreachable, and so the user can compare results.
class DeezerSource implements MusicSource {
  DeezerSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  MusicSourceId get id => MusicSourceId.deezer;

  @override
  Future<List<Track>> search(String query, {int limit = 50}) async {
    final uri = Uri.https('api.deezer.com', '/search', {
      'q': query,
      'limit': '$limit',
    });
    return _songs(await _requestJson(_client, uri));
  }

  @override
  Future<List<Track>> byMood(String mood, {int limit = 40}) =>
      search(mood, limit: limit);

  @override
  Future<List<Track>> charts({int limit = 25}) async {
    final uri = Uri.https('api.deezer.com', '/chart/0/tracks', {
      'limit': '$limit',
    });
    return _songs(await _requestJson(_client, uri));
  }

  @override
  Future<List<Track>> album(Track track, {int limit = 40}) async {
    final id = track.collectionId;
    if (id == null) {
      return search('${track.artist} ${track.album}', limit: limit);
    }
    final uri = Uri.https('api.deezer.com', '/album/$id/tracks', {
      'limit': '$limit',
    });
    // Album track payloads omit the cover, so carry the album's own artwork.
    return _songs(await _requestJson(_client, uri))
        .map((t) => t.withArtwork(track.artworkUrl))
        .toList();
  }

  @override
  Future<List<Track>> artist(Track track, {int limit = 40}) async {
    final id = track.artistId;
    if (id == null) return search(track.artist, limit: limit);
    final uri = Uri.https('api.deezer.com', '/artist/$id/top', {
      'limit': '$limit',
    });
    return _songs(await _requestJson(_client, uri));
  }

  List<Track> _songs(Map<String, dynamic> json) {
    final results = (json['data'] as List?) ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(Track.fromDeezer)
        .where((t) => t.artworkUrl.isNotEmpty)
        .toList();
  }
}

Future<Map<String, dynamic>> _requestJson(http.Client client, Uri uri) async {
  final http.Response response;
  try {
    response = await client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
  } catch (e) {
    throw MusicApiException('Нет сети — проверьте подключение.');
  }
  if (response.statusCode != 200) {
    throw MusicApiException('Каталог ответил ошибкой ${response.statusCode}.');
  }
  // iTunes serves its JSON as text/javascript, so decode the bytes ourselves
  // instead of relying on the content type.
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw MusicApiException('Неожиданный ответ каталога.');
  }
  if (decoded['error'] != null) {
    throw MusicApiException('Каталог отклонил запрос.');
  }
  return decoded;
}

/// Set with `--dart-define=WAVE_DEMO=true` to run against the bundled offline
/// catalogue instead of a live music API.
const kDemoMode = bool.fromEnvironment('WAVE_DEMO');

/// Curated browse rows shown on the Discover tab.
class Mood {
  const Mood(this.title, this.query, this.icon);

  final String title;

  /// What actually gets sent to the catalogue.
  final String query;

  /// Glyphs rather than emoji: emoji would pull a colour font over the network
  /// on web, and fall back to tofu when that request is blocked.
  final IconData icon;
}

const kMoods = <Mood>[
  Mood('Поздний вечер', 'lofi chill beats', CupertinoIcons.moon_stars),
  Mood('Адреналин', 'workout electronic', CupertinoIcons.bolt_fill),
  Mood('Золотой час', 'indie pop sunset', CupertinoIcons.sun_max),
  Mood('Фокус', 'ambient piano focus', CupertinoIcons.scope),
  Mood('Ретро', '80s synth pop', CupertinoIcons.recordingtape),
  Mood('Низы', 'bass house', CupertinoIcons.speaker_2_fill),
];

/// Facade the UI talks to; owns which [MusicSource] is currently active.
class MusicRepository {
  MusicRepository({MusicSource? itunes, MusicSource? deezer})
    : _sources = {
        MusicSourceId.itunes: itunes ?? ItunesSource(),
        MusicSourceId.deezer: deezer ?? DeezerSource(),
        MusicSourceId.demo: const DemoSource(),
      },
      activeId = kDemoMode ? MusicSourceId.demo : MusicSourceId.itunes;

  final Map<MusicSourceId, MusicSource> _sources;
  MusicSourceId activeId;

  MusicSource get active => _sources[activeId]!;

  Future<List<Track>> search(String query, {int limit = 50}) =>
      active.search(query, limit: limit);

  Future<List<Track>> charts({int limit = 25}) => active.charts(limit: limit);

  Future<List<Track>> byMood(Mood mood, {int limit = 40}) =>
      active.byMood(mood.query, limit: limit);

  /// Browsing an album or an artist stays on the catalogue the track came
  /// from, not whichever one happens to be selected.
  Future<List<Track>> album(Track track, {int limit = 40}) =>
      _sources[track.source]!.album(track, limit: limit);

  Future<List<Track>> artist(Track track, {int limit = 40}) =>
      _sources[track.source]!.artist(track, limit: limit);
}
