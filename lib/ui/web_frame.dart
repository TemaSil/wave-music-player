import 'package:flutter/widgets.dart';

import '../core/wave_theme.dart';

/// Keeps the phone layout phone-shaped on a desktop-sized window.
///
/// Everything in this app is laid out for a phone: a floating tab bar, a
/// single column of rows, a full-bleed Now Playing. Stretched across a 1600px
/// browser window it does not become a desktop app, it becomes a broken phone
/// app. On a wide viewport the app is therefore centred inside a phone-sized
/// frame, and — importantly — the [MediaQuery] handed to it reports the frame's
/// size, so layout, safe areas and the scaffold's own measurements all agree
/// with what is actually on screen.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  /// Below this the window is close enough to a phone to use directly.
  static const breakpoint = 700.0;

  static const _frameWidth = 414.0;
  static const _maxFrameHeight = 896.0;

  /// Breathing room around the frame so its rounded corners and shadow are
  /// actually visible rather than clipped by the window.
  static const _gutter = 48.0;

  /// Stands in for a phone's status bar and home indicator, so the chrome sits
  /// where it would on a device rather than flush against the frame edge.
  static const _framePadding = EdgeInsets.only(top: 24, bottom: 18);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < breakpoint) return child;

    // A short window (a laptop with browser chrome) gets a shorter phone
    // rather than a phone with its ends cut off.
    final frame = Size(
      _frameWidth,
      (media.size.height - _gutter).clamp(480.0, _maxFrameHeight),
    );

    return ColoredBox(
      color: const Color(0xFF0B0B0F),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(46),
            boxShadow: [
              BoxShadow(
                color: WaveColors.musicRed.withValues(alpha: 0.10),
                blurRadius: 90,
                spreadRadius: 10,
              ),
              const BoxShadow(color: Color(0xCC000000), blurRadius: 40),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(46),
            child: SizedBox(
              width: frame.width,
              height: frame.height,
              child: MediaQuery(
                data: media.copyWith(
                  size: frame,
                  padding: _framePadding,
                  viewPadding: _framePadding,
                  viewInsets: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
