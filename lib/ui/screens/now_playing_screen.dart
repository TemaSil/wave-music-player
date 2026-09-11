import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../audio/player_service.dart';
import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../../data/track.dart';
import '../widgets/artwork_image.dart';
import '../widgets/aurora_background.dart';
import '../widgets/like_button.dart';
import '../widgets/liquid_seek_bar.dart';
import '../widgets/marquee_text.dart';
import '../widgets/play_pause_button.dart';
import '../widgets/press_scale.dart';
import '../widgets/vinyl_artwork.dart';
import '../widgets/wave_visualizer.dart';

/// Shared Hero tag between the mini player's thumbnail and the full artwork.
const kNowPlayingHeroTag = 'wave.now-playing.artwork';

/// Slides the full player up over the shell, fading and lifting as it goes.
class NowPlayingRoute extends PageRouteBuilder<void> {
  NowPlayingRoute()
    : super(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        opaque: false,
        barrierColor: const Color(0x00000000),
        pageBuilder: (_, _, _) => const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondary, child) {
          final eased = CurvedAnimation(
            parent: animation,
            curve: WaveMotion.emphasized,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.16),
                end: Offset.zero,
              ).animate(eased),
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(eased),
                child: child,
              ),
            ),
          );
        },
      );
}

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  /// How far the sheet has been dragged down, in logical pixels.
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    // Only downward drags do anything; upward ones rubber-band to zero.
    setState(
      () => _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 600.0),
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > 130 || velocity > 700) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = WaveScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        services.player,
        services.favorites,
        services.ambience,
      ]),
      builder: (context, _) {
        final player = services.player;
        final palette = services.ambience.value;
        final track = player.current;

        if (track == null) {
          // The queue can empty while the screen is open; leave rather than
          // showing a dead player.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const SizedBox.shrink();
        }

        final dismissProgress = (_dragOffset / 320).clamp(0.0, 1.0);

        return GestureDetector(
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: AnimatedContainer(
            duration: _dragOffset == 0 ? WaveMotion.medium : Duration.zero,
            curve: WaveMotion.emphasized,
            transform: Matrix4.translationValues(0, _dragOffset, 0),
            child: Opacity(
              opacity: 1 - dismissProgress * 0.35,
              child: GlassScaffold(
                backgroundColor: WaveColors.abyss,
                statusBarStyle: GlassStatusBarStyle.light,
                background: _Backdrop(
                  track: track,
                  palette: palette,
                  playing: player.isPlaying,
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      _Grabber(palette: palette),
                      Expanded(
                        child: _Stage(
                          player: player,
                          palette: palette,
                          track: track,
                        ),
                      ),
                      _Controls(
                        services: services,
                        player: player,
                        palette: palette,
                        track: track,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Aurora field plus a heavily blurred copy of the artwork for depth.
class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.track,
    required this.palette,
    required this.playing,
  });

  final Track track;
  final WavePalette palette;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AuroraBackground(palette: palette, energy: playing ? 1 : 0),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: 0.30,
            duration: WaveMotion.palette,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 64, sigmaY: 64),
              child: ArtworkImage(url: track.thumbnailUrl, fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.palette});

  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Artwork, titles and visualiser — everything above the transport controls.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.player,
    required this.palette,
    required this.track,
  });

  final PlayerService player;
  final WavePalette palette;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On short screens the artwork yields space before anything else does.
        final artworkSide = (constraints.maxHeight * 0.58).clamp(140.0, 340.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: artworkSide,
              child: VinylArtwork(
                track: track,
                palette: palette,
                spinning: player.isPlaying,
                heroTag: kNowPlayingHeroTag,
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                height: 30,
                child: MarqueeText(
                  track.title,
                  style: WaveText.largeTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WaveText.caption.copyWith(
                  fontSize: 15,
                  color: palette.secondary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: WaveVisualizer(
                palette: palette,
                active: player.isPlaying,
                height: (constraints.maxHeight * 0.12).clamp(34.0, 64.0),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Seek bar, transport row and the secondary toggles beneath it.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.services,
    required this.player,
    required this.palette,
    required this.track,
  });

  final WaveServices services;
  final PlayerService player;
  final WavePalette palette;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiquidSeekBar(
            progress: player.progress,
            buffered: player.bufferedProgress,
            palette: palette,
            enabled: player.duration > Duration.zero,
            onScrub: player.scrubTo,
            onScrubEnd: (_) => player.commitScrub(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(player.position), style: WaveText.tiny),
                Text(
                  '-${formatDuration(player.duration - player.position)}',
                  style: WaveText.tiny,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToggleIcon(
                icon: CupertinoIcons.shuffle,
                active: player.shuffle,
                accent: palette.primary,
                onTap: player.toggleShuffle,
              ),
              _TransportIcon(
                icon: CupertinoIcons.backward_end_fill,
                onTap: player.previous,
              ),
              PlayPauseButton(
                isPlaying: player.isPlaying,
                isBusy: player.isBusy,
                onTap: player.toggle,
                accent: palette.primary,
                size: 72,
                quality: GlassQuality.premium,
              ),
              _TransportIcon(
                icon: CupertinoIcons.forward_end_fill,
                onTap: player.next,
              ),
              _ToggleIcon(
                icon: player.repeat == WaveRepeat.one
                    ? CupertinoIcons.repeat_1
                    : CupertinoIcons.repeat,
                active: player.repeat != WaveRepeat.off,
                accent: palette.primary,
                onTap: player.cycleRepeat,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LikeButton(
                liked: services.favorites.contains(track),
                onTap: () => services.favorites.toggle(track),
                size: 22,
              ),
              Flexible(
                child: Text(
                  '${track.source.label}  ·  preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WaveText.tiny,
                ),
              ),
              PressScale(
                onTap: () => _showQueue(context, services),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    CupertinoIcons.list_bullet,
                    size: 20,
                    color: WaveColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQueue(BuildContext context, WaveServices services) {
    GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      initialState: GlassSheetState.half,
      builder: (sheetContext) =>
          _QueueSheet(services: services, palette: palette),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({required this.services, required this.palette});

  final WaveServices services;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.player,
      builder: (context, _) {
        final player = services.player;
        final queue = player.queue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
              child: Text('Up next · ${queue.length}', style: WaveText.section),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrent = index == player.index;
                  return GlassListTile(
                    onTap: () => player.playQueue(queue, startIndex: index),
                    leading: ClipRSuperellipse(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.square(
                        dimension: 38,
                        child: ArtworkImage(
                          url: track.thumbnailUrl,
                          iconSize: 14,
                        ),
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WaveText.body.copyWith(
                        fontSize: 14,
                        color: isCurrent
                            ? palette.primary
                            : WaveColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WaveText.caption.copyWith(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.86,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 28, color: WaveColors.textPrimary),
      ),
    );
  }
}

/// Shuffle / repeat: tints and lifts onto a glass pill when active.
class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.88,
      child: AnimatedContainer(
        duration: WaveMotion.medium,
        curve: WaveMotion.emphasized,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? accent.withValues(alpha: 0.20)
              : const Color(0x00000000),
          boxShadow: [
            if (active)
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? accent : WaveColors.textTertiary,
        ),
      ),
    );
  }
}
