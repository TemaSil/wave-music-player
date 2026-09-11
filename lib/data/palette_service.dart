import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

import '../core/wave_theme.dart';
import 'track.dart';

/// Extracts a [WavePalette] from artwork so the whole UI can tint itself to
/// whatever is playing.
///
/// Results are memoised per track: decoding and histogramming a bitmap is far
/// too expensive to redo on every rebuild.
class PaletteService {
  final Map<String, WavePalette> _cache = {};
  final Map<String, Future<WavePalette>> _inFlight = {};

  /// The already-extracted palette, if there is one. Lets callers avoid a
  /// frame of the wrong colour when revisiting a track.
  WavePalette? cached(Track track) => _cache[track.uid];

  Future<WavePalette> of(Track track) {
    final hit = _cache[track.uid];
    if (hit != null) return Future.value(hit);
    return _inFlight.putIfAbsent(track.uid, () async {
      try {
        final palette = await _extract(track);
        _cache[track.uid] = palette;
        return palette;
      } catch (_) {
        // Artwork that will not load should not leave the UI colourless.
        _cache[track.uid] = WavePalette.fallback;
        return WavePalette.fallback;
      } finally {
        _inFlight.remove(track.uid);
      }
    });
  }

  Future<WavePalette> _extract(Track track) async {
    final url = track.thumbnailUrl;
    final ImageProvider provider = url.startsWith('assets/')
        ? AssetImage(url)
        : CachedNetworkImageProvider(url);

    final image = await _resolve(provider);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return WavePalette.fallback;

    return _quantise(data.buffer.asUint8List(), image.width, image.height);
  }

  /// Drives an [ImageProvider] to a decoded [ui.Image].
  ///
  /// Going through the provider (rather than fetching the bytes again) means
  /// network artwork is read from the same cache the UI already populated.
  Future<ui.Image> _resolve(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 10));
  }

  /// Number of hue buckets. 24 gives 15° per bucket — fine enough to separate
  /// a teal from a green, coarse enough that noise does not fragment a hue.
  static const _buckets = 24;

  WavePalette _quantise(Uint8List rgba, int width, int height) {
    final weight = List<double>.filled(_buckets, 0);
    final sumR = List<double>.filled(_buckets, 0);
    final sumG = List<double>.filled(_buckets, 0);
    final sumB = List<double>.filled(_buckets, 0);

    // Sample on a grid: ~4k pixels is plenty to characterise a cover, and
    // keeps extraction off the frame budget for large artwork.
    final step = math.max(1, math.sqrt(width * height / 4096).round());

    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        final i = (y * width + x) * 4;
        if (i + 3 >= rgba.length) continue;
        if (rgba[i + 3] < 128) continue;

        final r = rgba[i] / 255;
        final g = rgba[i + 1] / 255;
        final b = rgba[i + 2] / 255;

        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final lightness = (maxC + minC) / 2;
        final delta = maxC - minC;

        // Near-black and near-white pixels carry no usable hue.
        if (lightness < 0.06 || lightness > 0.96) continue;

        final saturation = delta == 0
            ? 0.0
            : delta / (1 - (2 * lightness - 1).abs()).clamp(0.0001, 1.0);
        if (saturation < 0.08) continue;

        final hue = _hue(r, g, b, maxC, delta);
        final bucket = ((hue / 360) * _buckets).floor().clamp(0, _buckets - 1);

        // Saturated mid-tones are what reads as "the colour of this cover".
        final score = saturation * (1 - (lightness - 0.5).abs());
        weight[bucket] += score;
        sumR[bucket] += r * score;
        sumG[bucket] += g * score;
        sumB[bucket] += b * score;
      }
    }

    final ranked = List.generate(_buckets, (i) => i)
      ..sort((a, b) => weight[b].compareTo(weight[a]));

    final picks = <Color>[];
    final chosen = <int>[];
    for (final bucket in ranked) {
      if (weight[bucket] <= 0) break;
      // Skip hues adjacent to one already taken, so the trio stays distinct.
      final tooClose = chosen.any((other) {
        final gap = (other - bucket).abs();
        return math.min(gap, _buckets - gap) < 2;
      });
      if (tooClose) continue;

      chosen.add(bucket);
      picks.add(
        _boost(
          Color.from(
            alpha: 1,
            red: sumR[bucket] / weight[bucket],
            green: sumG[bucket] / weight[bucket],
            blue: sumB[bucket] / weight[bucket],
          ),
        ),
      );
      if (picks.length == 3) break;
    }

    if (picks.isEmpty) return WavePalette.fallback;
    // Monochrome artwork yields one or two hues; rotate to fill the trio.
    while (picks.length < 3) {
      picks.add(_rotate(picks[picks.length - 1], 34));
    }
    return WavePalette(picks[0], picks[1], picks[2]);
  }

  double _hue(double r, double g, double b, double maxC, double delta) {
    if (delta == 0) return 0;
    final double hue;
    if (maxC == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (maxC == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
    return hue < 0 ? hue + 360 : hue;
  }

  /// Pushes washed-out artwork colours toward something that still reads as a
  /// glow on a near-black background.
  Color _boost(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 1.0))
        .withLightness(hsl.lightness.clamp(0.44, 0.72))
        .toColor();
  }

  Color _rotate(Color color, double degrees) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + degrees) % 360).toColor();
  }
}
