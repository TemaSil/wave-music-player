import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/track.dart';

/// How the queue repeats.
enum WaveRepeat { off, all, one }

/// Owns the [AudioPlayer] and exposes the little bit of state the UI needs.
///
/// Deliberately a plain [ChangeNotifier]: the whole app is one shell plus one
/// player, so a state-management package would only add indirection.
class PlayerService extends ChangeNotifier {
  PlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _wire();
  }

  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  List<Track> _queue = const [];
  int _index = -1;
  Duration _position = Duration.zero;
  Duration _buffered = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _busy = false;
  bool _shuffle = false;
  WaveRepeat _repeat = WaveRepeat.off;
  String? _error;

  /// Set while the user drags the seek bar, so incoming position events do not
  /// fight the thumb.
  Duration? _scrubTarget;

  List<Track> get queue => List.unmodifiable(_queue);
  int get index => _index;
  Track? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get hasTrack => current != null;
  bool get isPlaying => _playing;
  bool get isBusy => _busy;
  bool get shuffle => _shuffle;
  WaveRepeat get repeat => _repeat;
  String? get error => _error;

  Duration get position => _scrubTarget ?? _position;
  Duration get buffered => _buffered;

  /// Falls back to the catalogue's declared length before the stream reports one.
  Duration get duration => _duration > Duration.zero
      ? _duration
      : (current?.duration ?? Duration.zero);

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get bufferedProgress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_buffered.inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool isCurrent(Track track) => current?.uid == track.uid;

  void _wire() {
    _subs.addAll([
      _player.playerStateStream.listen((state) {
        _playing = state.playing;
        _busy =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        notifyListeners();
      }),
      _player.positionStream.listen((p) {
        _position = p;
        if (_scrubTarget == null) notifyListeners();
      }),
      _player.bufferedPositionStream.listen((p) {
        _buffered = p;
        notifyListeners();
      }),
      _player.durationStream.listen((d) {
        _duration = d ?? Duration.zero;
        notifyListeners();
      }),
      _player.currentIndexStream.listen((i) {
        if (i != null && i != _index) {
          _index = i;
          notifyListeners();
        }
      }),
    ]);
  }

  /// Configures the OS audio session for music playback. Safe to call once at
  /// startup; failures are non-fatal (desktop/web have no session to configure).
  static Future<void> configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // No platform audio session available — playback still works.
    }
  }

  /// Replaces the queue with [tracks] and starts at [startIndex].
  ///
  /// Unplayable entries (no preview stream) are dropped first so that skipping
  /// never lands on a dead item.
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    final playable = tracks.where((t) => t.isPlayable).toList();
    if (playable.isEmpty) {
      _error = 'У этих треков нет превью для воспроизведения.';
      notifyListeners();
      return;
    }

    // Map the requested index through the filtered list.
    final requested = startIndex >= 0 && startIndex < tracks.length
        ? tracks[startIndex]
        : null;
    var resolved = requested == null
        ? 0
        : playable.indexWhere((t) => t.uid == requested.uid);
    if (resolved < 0) resolved = 0;

    // Tapping the track that is already playing should just toggle, not reload.
    if (_sameQueue(playable) && _index == resolved) {
      await toggle();
      return;
    }

    _error = null;
    _queue = playable;
    _index = resolved;
    _duration = Duration.zero;
    _position = Duration.zero;
    notifyListeners();

    try {
      await _player.setAudioSources(
        [for (final t in playable) _sourceFor(t)],
        initialIndex: resolved,
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (e) {
      _error = 'Не удалось начать воспроизведение.';
      notifyListeners();
    }
  }

  /// Demo tracks point at bundled assets; everything else is a remote preview.
  ///
  /// The tag has to be a [MediaItem]: that is what `just_audio_background`
  /// reads to populate the notification and the lock screen, so a plain id
  /// would leave the media session blank.
  AudioSource _sourceFor(Track track) {
    final url = track.previewUrl!;
    final tag = MediaItem(
      id: track.uid,
      title: track.title,
      artist: track.artist,
      album: track.album.isEmpty ? null : track.album,
      duration: track.duration > Duration.zero ? track.duration : null,
      // Demo artwork lives in the asset bundle, which the platform
      // notification cannot load, so only remote covers are offered.
      artUri: track.artworkUrl.startsWith('http')
          ? Uri.tryParse(track.artworkUrl)
          : null,
    );
    return url.startsWith('assets/')
        ? AudioSource.asset(url, tag: tag)
        : AudioSource.uri(Uri.parse(url), tag: tag);
  }

  bool _sameQueue(List<Track> other) {
    if (other.length != _queue.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i].uid != _queue[i].uid) return false;
    }
    return true;
  }

  Future<void> toggle() => _playing ? _player.pause() : _player.play();

  /// Dismisses the last error banner.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_repeat == WaveRepeat.all && _queue.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  /// Restarts the track first, like every other music app, and only steps back
  /// once you are near the beginning.
  Future<void> previous() async {
    if (_position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> seekToFraction(double fraction) async {
    final total = duration;
    if (total <= Duration.zero) return;
    await _player.seek(total * fraction.clamp(0.0, 1.0));
  }

  /// Preview the target position while the thumb is held down.
  void scrubTo(double fraction) {
    final total = duration;
    if (total <= Duration.zero) return;
    _scrubTarget = total * fraction.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> commitScrub() async {
    final target = _scrubTarget;
    _scrubTarget = null;
    if (target != null) await _player.seek(target);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    if (_shuffle) await _player.shuffle();
    await _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    _repeat = switch (_repeat) {
      WaveRepeat.off => WaveRepeat.all,
      WaveRepeat.all => WaveRepeat.one,
      WaveRepeat.one => WaveRepeat.off,
    };
    await _player.setLoopMode(switch (_repeat) {
      WaveRepeat.off => LoopMode.off,
      WaveRepeat.all => LoopMode.all,
      WaveRepeat.one => LoopMode.one,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
