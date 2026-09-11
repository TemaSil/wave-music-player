import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Static colour tokens for Wave.
///
/// The app is dark-first: artwork supplies the hue, these tokens supply the
/// structure (ink, text, hairlines) so that a dark cover and a neon cover both
/// stay legible.
abstract final class WaveColors {
  /// Deepest background tone for the aurora skin — everything floats above it.
  static const abyss = Color(0xFF05050B);

  /// Apple Music is pure black in dark mode; anything lighter reads as a
  /// knock-off immediately.
  static const appleBackground = Color(0xFF000000);

  /// Apple Music's accent, taken from the reference demo the package ships.
  static const musicRed = Color(0xFFFF2D55);

  /// The grey Apple Music fills its cards and rows with.
  static const appleCard = Color(0xFF2C2C2E);

  /// Default accents, used until artwork colours have been extracted.
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const magenta = Color(0xFFF472B6);

  static const textPrimary = Color(0xFFF6F6FB);
  static const textSecondary = Color(0xFFA0A0B8);
  static const textTertiary = Color(0xFF6A6A82);

  /// Hairline used for dividers and inactive track fills.
  static const hairline = Color(0x1AFFFFFF);
}

/// A trio of colours sampled from the current artwork.
///
/// Every ambient surface in the app (background aurora, visualiser, progress
/// bar, glow) reads from a single palette so the whole screen shifts together
/// when the track changes.
@immutable
class WavePalette {
  const WavePalette(this.primary, this.secondary, this.tertiary);

  /// Shown before any artwork has been analysed.
  static const fallback = WavePalette(
    WaveColors.violet,
    WaveColors.cyan,
    WaveColors.magenta,
  );

  /// The fixed palette used when live artwork colour is switched off, so every
  /// accent-driven widget keeps working without special-casing the skin.
  static const appleMusic = WavePalette(
    WaveColors.musicRed,
    Color(0xFFFF6482),
    Color(0xFFE2072C),
  );

  final Color primary;
  final Color secondary;
  final Color tertiary;

  List<Color> get all => [primary, secondary, tertiary];

  static WavePalette lerp(WavePalette a, WavePalette b, double t) {
    return WavePalette(
      Color.lerp(a.primary, b.primary, t)!,
      Color.lerp(a.secondary, b.secondary, t)!,
      Color.lerp(a.tertiary, b.tertiary, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WavePalette &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.tertiary == tertiary;

  @override
  int get hashCode => Object.hash(primary, secondary, tertiary);
}

/// Tween for [WavePalette], so ambient surfaces cross-fade to the new
/// artwork's colours instead of snapping.
class WavePaletteTween extends Tween<WavePalette> {
  WavePaletteTween({super.begin, super.end});

  @override
  WavePalette lerp(double t) => WavePalette.lerp(begin!, end!, t);
}

/// Shared durations and curves so transitions across screens feel related.
abstract final class WaveMotion {
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 700);
  static const palette = Duration(milliseconds: 900);

  /// iOS-style emphasised ease — quick out, long settle.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Overshoots slightly past the target, for taps and likes.
  static const overshoot = Cubic(0.34, 1.4, 0.64, 1.0);
}

/// Cupertino's own family name. On iOS and macOS the engine resolves it to the
/// real SF Pro; everywhere else it does not exist, and Flutter falls through to
/// [_fallback].
const _systemFamily = 'CupertinoSystemText';

/// Inter, bundled in `assets/fonts/`. Without it Android and web render the
/// whole app in Roboto, which is the single loudest signal that this is not an
/// Apple interface.
const _fallback = <String>['Inter'];

abstract final class WaveText {
  static const largeTitle = TextStyle(
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: WaveColors.textPrimary,

    fontFamily: _systemFamily,
    fontFamilyFallback: _fallback,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: WaveColors.textPrimary,

    fontFamily: _systemFamily,
    fontFamilyFallback: _fallback,
  );

  static const section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    color: WaveColors.textPrimary,

    fontFamily: _systemFamily,
    fontFamilyFallback: _fallback,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: WaveColors.textPrimary,

    fontFamily: _systemFamily,
    fontFamilyFallback: _fallback,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: WaveColors.textSecondary,

    fontFamily: _systemFamily,
    fontFamilyFallback: _fallback,
  );

  static const tiny = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: WaveColors.textTertiary,

    fontFamily: _systemFamily,
    fontFamilyFallback: _fallback,
  );
}

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (minutes >= 60) {
    final hours = d.inHours;
    return '$hours:${minutes.remainder(60).toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// Glass tuned to match Apple Music rather than a generic frosted panel.
///
/// The values come from the Apple Music reference demo shipped with
/// `liquid_glass_widgets`, and they are not what you would guess: the blur is
/// almost nothing (2) while the glass is thick (30) with the Fresnel rim
/// switched off entirely. Heavy blur with a bright rim — the obvious setting —
/// is exactly what makes a fake iOS 26 look foggy instead of solid.
LiquidGlassSettings appleMusicGlass({double alpha = 0.80, Color? tint}) {
  return LiquidGlassSettings(
    glassColor: (tint ?? const Color(0xFF1C1C1E)).withValues(alpha: alpha),
    thickness: 30,
    blur: 2,
    chromaticAberration: 0.01,
    lightAngle: GlassDefaults.lightAngle,
    lightIntensity: 0.2,
    ambientStrength: 0,
    refractiveIndex: 1.2,
    fresnelStrength: 0,
    saturation: 1.2,
  );
}
