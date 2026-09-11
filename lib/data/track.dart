import 'package:flutter/foundation.dart';

/// Which public catalogue a [Track] came from.
enum MusicSourceId {
  itunes('itunes', 'Apple / iTunes'),
  deezer('deezer', 'Deezer'),
  demo('demo', 'Офлайн-демо');

  const MusicSourceId(this.key, this.label);

  final String key;
  final String label;

  static MusicSourceId fromKey(String? key) =>
      values.firstWhere((s) => s.key == key, orElse: () => itunes);
}

/// A single playable item.
///
/// Both catalogues we talk to hand out 30-second preview streams, so
/// [previewUrl] is what actually gets played. Tracks without one are still
/// worth showing (they carry artwork and metadata) but are not queueable —
/// see [isPlayable].
@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.source,
    this.previewUrl,
    this.duration = Duration.zero,
    this.genre = '',
    this.releaseYear,
    this.collectionId,
    this.artistId,
  });

  final String id;
  final String title;
  final String artist;
  final String album;

  /// Highest resolution artwork URL we can construct for this source.
  final String artworkUrl;
  final String? previewUrl;
  final Duration duration;
  final String genre;
  final int? releaseYear;

  /// Catalogue ids for the album and the artist this track belongs to, used to
  /// browse to them. Null when the catalogue did not supply one — the
  /// repository falls back to a text search in that case.
  final String? collectionId;
  final String? artistId;

  final MusicSourceId source;

  bool get isPlayable => previewUrl != null && previewUrl!.isNotEmpty;

  /// Stable key across sources, used for favourites and queue identity.
  String get uid => '${source.key}:$id';

  /// A smaller artwork variant for list rows, to keep scrolling cheap.
  String get thumbnailUrl {
    switch (source) {
      case MusicSourceId.itunes:
        return artworkUrl.replaceAll(RegExp(r'/\d+x\d+bb'), '/200x200bb');
      case MusicSourceId.deezer:
      case MusicSourceId.demo:
        return artworkUrl;
    }
  }

  /// iTunes artwork URLs embed their size, so we can ask for a bigger one.
  static String _upscaleItunesArtwork(String url, int size) =>
      url.replaceAll(RegExp(r'/\d+x\d+bb'), '/${size}x${size}bb');

  factory Track.fromItunes(Map<String, dynamic> json) {
    final artwork =
        (json['artworkUrl100'] ?? json['artworkUrl60'] ?? '') as String;
    final released = json['releaseDate'] as String?;
    return Track(
      id: '${json['trackId'] ?? json['collectionId'] ?? artwork.hashCode}',
      title:
          (json['trackName'] ?? json['collectionName'] ?? 'Unknown') as String,
      artist: (json['artistName'] ?? 'Unknown artist') as String,
      album: (json['collectionName'] ?? '') as String,
      artworkUrl: _upscaleItunesArtwork(artwork, 600),
      previewUrl: json['previewUrl'] as String?,
      duration: Duration(milliseconds: (json['trackTimeMillis'] as int?) ?? 0),
      genre: (json['primaryGenreName'] ?? '') as String,
      releaseYear: released != null && released.length >= 4
          ? int.tryParse(released.substring(0, 4))
          : null,
      source: MusicSourceId.itunes,
    );
  }

  factory Track.fromDeezer(Map<String, dynamic> json) {
    final album = json['album'] as Map<String, dynamic>?;
    final artist = json['artist'] as Map<String, dynamic>?;
    return Track(
      id: '${json['id']}',
      title: (json['title_short'] ?? json['title'] ?? 'Unknown') as String,
      artist: (artist?['name'] ?? 'Unknown artist') as String,
      album: (album?['title'] ?? '') as String,
      artworkUrl:
          (album?['cover_xl'] ??
                  album?['cover_big'] ??
                  album?['cover_medium'] ??
                  '')
              as String,
      previewUrl: json['preview'] as String?,
      duration: Duration(seconds: (json['duration'] as int?) ?? 0),
      collectionId: album?['id']?.toString(),
      artistId: artist?['id']?.toString(),
      source: MusicSourceId.deezer,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'artworkUrl': artworkUrl,
    'previewUrl': previewUrl,
    'durationMs': duration.inMilliseconds,
    'genre': genre,
    'releaseYear': releaseYear,
    'source': source.key,
  };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: (json['album'] ?? '') as String,
    artworkUrl: (json['artworkUrl'] ?? '') as String,
    previewUrl: json['previewUrl'] as String?,
    duration: Duration(milliseconds: (json['durationMs'] as int?) ?? 0),
    genre: (json['genre'] ?? '') as String,
    releaseYear: json['releaseYear'] as int?,
    source: MusicSourceId.fromKey(json['source'] as String?),
  );

  /// Deezer's album-track payloads omit the cover; this carries the album's
  /// own artwork onto them.
  Track withArtwork(String url) => Track(
    id: id,
    title: title,
    artist: artist,
    album: album,
    artworkUrl: url,
    previewUrl: previewUrl,
    duration: duration,
    genre: genre,
    releaseYear: releaseYear,
    collectionId: collectionId,
    artistId: artistId,
    source: source,
  );

  @override
  bool operator ==(Object other) => other is Track && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'Track($uid, $title — $artist)';
}
