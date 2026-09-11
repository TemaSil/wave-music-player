import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// Playback position, published separately from [notifyListeners].
  ///
  /// The position stream fires many times a second. Routing it through
  /// [ChangeNotifier] rebuilt every screen that listens to the player — whole
  /// lists, every artwork, every row — at that rate. Only the handful of
  /// widgets that actually draw a clock or a progress bar listen here; the
  /// notifier itself now fires only when something structural changes: the
  /// track, the queue, play/pause, shuffle, repeat, duration, an error.
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);

  /// Buffered position, published on the same terms as [positionNotifier].
  final ValueNotifier<Duration> bufferedNotifier = ValueNotifier(Duration.zero);

  /// Output volume as the user set it, 0..1. Its own notifier for the same
  /// reason as the position: dragging the slider should not rebuild the screen
  /// behind it. The value actually sent to the engine is this multiplied by
  /// the automix fade, so a fade never moves the slider.
  final ValueNotifier<double> volumeNotifier = ValueNotifier(1);

  /// Fades the end of one track into the start of the next instead of cutting.
  ///
  /// This is the audible half of what iOS 26 calls Automix. The other half —
  /// picking a transition point by beat and matching tempo between the two
  /// tracks — needs tempo and key analysis of the audio, which nothing here
  /// does and which 30-second preview streams would not support anyway. What
  /// this does is real and honest: a volume ramp out of the last
  /// [automixFade] of a track and back in over the first [automixFade] of the
  /// next.
  bool automix = false;

  /// How long each side of the transition takes.
  static const automixFade = Duration(seconds: 5);

  Timer? _fadeTicker;

  /// 0..1, multiplied into the engine volume. 1 outside a transition.
  double _fadeGain = 1;

  /// Set when a track starts, so the fade-in knows where it began.
  Duration _fadeInFrom = Duration.zero;

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
        if (_scrubTarget == null) positionNotifier.value = p;
      }),
      _player.bufferedPositionStream.listen((p) {
        _buffered = p;
        bufferedNotifier.value = p;
      }),
      _player.durationStream.listen((d) {
        _duration = d ?? Duration.zero;
        notifyListeners();
      }),
      _player.currentIndexStream.listen((i) {
        if (i != null && i != _index) {
          _index = i;
          // A new track begins silent when automix is on, and the ticker ramps
          // it up; without this the fade-in would start at full volume.
          if (automix) {
            _fadeInFrom = Duration.zero;
            _applyGain(0);
          }
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

  /// Whether the notification permission has already been dealt with, so the
  /// system prompt appears at most once per launch.
  bool _askedForNotifications = false;

  /// Android 13 and later hide the media notification — and with it the lock
  /// screen controls — unless POST_NOTIFICATIONS has been granted at runtime.
  /// Asked on the first play rather than at launch, so the prompt arrives with
  /// something to explain it.
  Future<void> _ensureNotifications() async {
    if (_askedForNotifications) return;
    _askedForNotifications = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) await Permission.notification.request();
    } catch (_) {
      // A missing prompt is not worth failing playback over.
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

    unawaited(_ensureNotifications());

    _error = null;
    _queue = playable;
    _index = resolved;
    _duration = Duration.zero;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    bufferedNotifier.value = Duration.zero;
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
    positionNotifier.value = _scrubTarget!;
  }

  Future<void> commitScrub() async {
    final target = _scrubTarget;
    _scrubTarget = null;
    if (target != null) await _player.seek(target);
    positionNotifier.value = _position;
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    volumeNotifier.value = clamped;
    await _applyGain(_fadeGain);
  }

  /// Pushes [gain] × the user's volume to the engine.
  Future<void> _applyGain(double gain) async {
    _fadeGain = gain.clamp(0.0, 1.0);
    await _player.setVolume(volumeNotifier.value * _fadeGain);
  }

  /// Starts or stops the transition ticker to match [automix] and playback.
  void _syncFadeTicker() {
    final wanted = automix && _playing;
    if (wanted == (_fadeTicker != null)) return;
    if (!wanted) {
      _fadeTicker?.cancel();
      _fadeTicker = null;
      // Leaving automix mid-fade must not strand the volume low.
      unawaited(_applyGain(1));
      return;
    }
    _fadeTicker = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _tickFade(),
    );
  }

  void _tickFade() {
    final total = duration;
    if (total <= Duration.zero) return;

    final fade = automixFade;
    final remaining = total - _position;
    final sinceStart = _position - _fadeInFrom;

    final double gain;
    if (remaining <= fade && _player.hasNext) {
      // Ramp out — but only with somewhere to go, so the last track of a
      // queue ends at full volume rather than fading into nothing.
      gain = (remaining.inMilliseconds / fade.inMilliseconds).clamp(0.0, 1.0);
    } else if (sinceStart < fade) {
      gain = (sinceStart.inMilliseconds / fade.inMilliseconds).clamp(0.0, 1.0);
    } else {
      gain = 1;
    }

    // Only talk to the engine when the value actually moved.
    if ((gain - _fadeGain).abs() > 0.01 || (gain == 1 && _fadeGain != 1)) {
      unawaited(_applyGain(gain));
    }
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

  /// Turns transitions on or off from settings.
  void setAutomix(bool value) {
    if (automix == value) return;
    automix = value;
    _fadeInFrom = _position;
    _syncFadeTicker();
    if (!value) unawaited(_applyGain(1));
    notifyListeners();
  }

  @override
  void dispose() {
    _fadeTicker?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    positionNotifier.dispose();
    bufferedNotifier.dispose();
    volumeNotifier.dispose();
    super.dispose();
  }
}
