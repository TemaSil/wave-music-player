import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/wave_theme.dart';
import 'package:wave/data/track.dart';

void main() {
  group('Track.fromItunes', () {
    const json = <String, dynamic>{
      'wrapperType': 'track',
      'kind': 'song',
      'trackId': 1440857781,
      'trackName': 'Get Lucky',
      'artistName': 'Daft Punk',
      'collectionName': 'Random Access Memories',
      'artworkUrl100':
          'https://is1-ssl.mzstatic.com/image/thumb/abc/100x100bb.jpg',
      'previewUrl': 'https://audio-ssl.itunes.apple.com/preview.m4a',
      'trackTimeMillis': 369626,
      'primaryGenreName': 'Pop',
      'releaseDate': '2013-05-17T07:00:00Z',
    };

    test('maps the fields the UI relies on', () {
      final track = Track.fromItunes(json);
      expect(track.id, '1440857781');
      expect(track.title, 'Get Lucky');
      expect(track.artist, 'Daft Punk');
      expect(track.album, 'Random Access Memories');
      expect(track.duration, const Duration(milliseconds: 369626));
      expect(track.releaseYear, 2013);
      expect(track.isPlayable, isTrue);
      expect(track.uid, 'itunes:1440857781');
    });

    test('requests a larger artwork than the feed returns', () {
      final track = Track.fromItunes(json);
      expect(track.artworkUrl, endsWith('/600x600bb.jpg'));
      expect(track.thumbnailUrl, endsWith('/200x200bb.jpg'));
    });

    test('is not playable without a preview stream', () {
      final track = Track.fromItunes({...json}..remove('previewUrl'));
      expect(track.isPlayable, isFalse);
    });
  });

  group('Track.fromDeezer', () {
    test('reads the nested album and artist objects', () {
      final track = Track.fromDeezer(const {
        'id': 3135556,
        'title': 'Harder, Better, Faster, Stronger',
        'title_short': 'Harder, Better, Faster, Stronger',
        'duration': 224,
        'preview': 'https://cdns-preview.dzcdn.net/preview.mp3',
        'artist': {'name': 'Daft Punk'},
        'album': {
          'title': 'Discovery',
          'cover_xl': 'https://e-cdns.dzcdn.net/cover.jpg',
        },
      });

      expect(track.uid, 'deezer:3135556');
      expect(track.artist, 'Daft Punk');
      expect(track.album, 'Discovery');
      expect(track.duration, const Duration(seconds: 224));
      expect(track.isPlayable, isTrue);
    });
  });

  test('survives a round trip through JSON', () {
    const original = Track(
      id: '42',
      title: 'Midnight',
      artist: 'Someone',
      album: 'Nocturne',
      artworkUrl: 'https://example.test/600x600bb.jpg',
      previewUrl: 'https://example.test/preview.m4a',
      duration: Duration(seconds: 187),
      genre: 'Electronic',
      releaseYear: 2024,
      source: MusicSourceId.deezer,
    );

    final restored = Track.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.title, original.title);
    expect(restored.duration, original.duration);
    expect(restored.source, MusicSourceId.deezer);
  });

  test('tracks with the same uid compare equal', () {
    const a = Track(
      id: '1',
      title: 'A',
      artist: 'X',
      album: '',
      artworkUrl: '',
      source: MusicSourceId.itunes,
    );
    const b = Track(
      id: '1',
      title: 'Different title',
      artist: 'X',
      album: '',
      artworkUrl: '',
      source: MusicSourceId.itunes,
    );
    expect(a, b);
    expect({a, b}, hasLength(1));
  });

  group('formatDuration', () {
    test('pads seconds', () {
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    });

    test('adds an hours field past 60 minutes', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });
}
