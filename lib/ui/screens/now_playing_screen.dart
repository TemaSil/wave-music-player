import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../audio/player_service.dart';
import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../../data/track.dart';
import '../widgets/artwork_image.dart';
import '../widgets/aurora_background.dart';
import '../widgets/liquid_seek_bar.dart';
import '../widgets/marquee_text.dart';
import '../widgets/press_scale.dart';
import '../widgets/vinyl_artwork.dart';
import '../widgets/wave_visualizer.dart';
import 'collection_screen.dart';

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
        services.appearance,
      ]),
      builder: (context, _) {
        final player = services.player;
        // Always the artwork's own colours here: Apple Music tints Now Playing
        // from the cover even while the rest of the app stays black.
        final palette = services.ambience.artwork;
        final track = player.current;

        if (track == null) {
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
                backgroundColor: WaveColors.appleBackground,
                statusBarStyle: GlassStatusBarStyle.light,
                background: _Backdrop(
                  track: track,
                  palette: palette,
                  playing: player.isPlaying,
                  aurora: services.appearance.usesLiveColour,
                  animate: services.appearance.ambientMotion,
                ),
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const _Grabber(),
                        Expanded(
                          child: _Artwork(
                            track: track,
                            palette: palette,
                            playing: player.isPlaying,
                            vinyl: services.appearance.showVinyl,
                          ),
                        ),
                        _TitleRow(
                          track: track,
                          palette: palette,
                          services: services,
                        ),
                        if (services.appearance.showVisualizer) ...[
                          const SizedBox(height: 10),
                          WaveVisualizer(
                            palette: palette,
                            active: player.isPlaying,
                            height: 40,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _Scrubber(player: player, palette: palette),
                        const SizedBox(height: 10),
                        _Transport(player: player),
                        const SizedBox(height: 18),
                        _VolumeRow(player: player, palette: palette),
                        const SizedBox(height: 10),
                        _BottomRow(
                          services: services,
                          track: track,
                          palette: palette,
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
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

/// Blurred artwork behind everything, exactly as Apple Music does it.
class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.track,
    required this.palette,
    required this.playing,
    required this.aurora,
    required this.animate,
  });

  final Track track;
  final WavePalette palette;
  final bool playing;
  final bool aurora;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Opaque floor first. The route is non-opaque so it can fade over the
        // shell, which means anything translucent above this shows the list
        // underneath — the gradient below starts at 55% alpha.
        const ColoredBox(color: WaveColors.appleBackground),
        if (aurora)
          AuroraBackground(
            palette: palette,
            energy: playing ? 1 : 0,
            animate: animate,
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.primary.withValues(alpha: 0.55),
                  palette.tertiary.withValues(alpha: 0.28),
                  WaveColors.appleBackground,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        IgnorePointer(
          child: Opacity(
            opacity: aurora ? 0.30 : 0.45,
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
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
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

/// Square cover that shrinks when paused.
///
/// This is Apple Music's signature Now Playing move, and it does more work than
/// it looks: the size change is the main feedback that playback stopped, which
/// is why the screen reads correctly even with the transport row out of view.
class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.track,
    required this.palette,
    required this.playing,
    required this.vinyl,
  });

  final Track track;
  final WavePalette palette;
  final bool playing;
  final bool vinyl;

  @override
  Widget build(BuildContext context) {
    if (vinyl) {
      return VinylArtwork(
        track: track,
        palette: palette,
        spinning: playing,
        heroTag: kNowPlayingHeroTag,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final radius = BorderRadius.circular(side * 0.045);
        return Align(
          // Sits just above the title, the way Apple Music stacks them. The
          // scale animation still pivots on the artwork's own centre, so
          // pausing opens a gap under the cover rather than shifting it.
          alignment: Alignment.bottomCenter,
          child: AnimatedScale(
            scale: playing ? 1.0 : 0.82,
            duration: const Duration(milliseconds: 420),
            curve: WaveMotion.emphasized,
            child: Hero(
              tag: kNowPlayingHeroTag,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.55),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: SizedBox.square(
                    dimension: side,
                    child: ArtworkImage(url: track.artworkUrl, iconSize: 48),
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

/// Title and artist on the left, the overflow menu on the right.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.track,
    required this.palette,
    required this.services,
  });

  final Track track;
  final WavePalette palette;
  final WaveServices services;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 26,
                  child: MarqueeText(
                    track.title,
                    style: WaveText.title.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openArtist(context, track),
                  child: SizedBox(
                    height: 24,
                    child: MarqueeText(
                      track.artist,
                      style: WaveText.title.copyWith(
                        fontSize: 22,
                        color: palette.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CircleGlyph(
            icon: CupertinoIcons.ellipsis,
            label: 'Ещё',
            onTap: () => showTrackActions(context, track, services),
          ),
        ],
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.player, required this.palette});

  final PlayerService player;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    // Only this strip follows the position stream; the rest of the screen
    // rebuilds when the track changes, not many times a second.
    return ValueListenableBuilder<Duration>(
      valueListenable: player.positionNotifier,
      builder: (context, position, _) {
        final total = player.duration;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: player.bufferedNotifier,
              builder: (context, _, _) => LiquidSeekBar(
                progress: player.progress,
                buffered: player.bufferedProgress,
                palette: palette,
                enabled: total > Duration.zero,
                onScrub: player.scrubTo,
                onScrubEnd: (_) => player.commitScrub(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(position), style: WaveText.tiny),
                  Text(
                    '-${formatDuration(total - position)}',
                    style: WaveText.tiny,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Plain glyphs, not buttons. Apple Music puts no surface behind these.
class _Transport extends StatelessWidget {
  const _Transport({required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Glyph(
          icon: CupertinoIcons.backward_end_fill,
          label: 'Предыдущий',
          size: 32,
          onTap: player.previous,
        ),
        SizedBox(
          width: 74,
          child: Center(
            child: _Glyph(
              icon: player.isPlaying
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              label: player.isPlaying ? 'Пауза' : 'Играть',
              size: 46,
              onTap: player.toggle,
            ),
          ),
        ),
        _Glyph(
          icon: CupertinoIcons.forward_end_fill,
          label: 'Следующий',
          size: 32,
          onTap: player.next,
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.player, required this.palette});

  final PlayerService player;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          CupertinoIcons.volume_down,
          size: 15,
          color: WaveColors.textPrimary.withValues(alpha: 0.5),
        ),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: player.volumeNotifier,
            builder: (context, volume, _) => LiquidSeekBar(
              progress: volume,
              buffered: 0,
              palette: palette,
              onScrub: player.setVolume,
              onScrubEnd: player.setVolume,
            ),
          ),
        ),
        Icon(
          CupertinoIcons.volume_up,
          size: 15,
          color: WaveColors.textPrimary.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

/// Shuffle, repeat, like and the queue — Apple Music's bottom strip.
class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.services,
    required this.track,
    required this.palette,
  });

  final WaveServices services;
  final Track track;
  final WavePalette palette;

  @override
  Widget build(BuildContext context) {
    final player = services.player;
    final liked = services.favorites.contains(track);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Glyph(
          icon: CupertinoIcons.shuffle,
          label: 'Перемешать',
          size: 20,
          active: player.shuffle,
          accent: palette.primary,
          onTap: player.toggleShuffle,
        ),
        _Glyph(
          icon: liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          label: liked ? 'Убрать из медиатеки' : 'В медиатеку',
          size: 22,
          active: liked,
          accent: palette.primary,
          onTap: () => services.favorites.toggle(track),
        ),
        _Glyph(
          icon: player.repeat == WaveRepeat.one
              ? CupertinoIcons.repeat_1
              : CupertinoIcons.repeat,
          label: 'Повтор',
          size: 20,
          active: player.repeat != WaveRepeat.off,
          accent: palette.primary,
          onTap: player.cycleRepeat,
        ),
        _Glyph(
          icon: CupertinoIcons.list_bullet,
          label: 'Очередь',
          size: 20,
          onTap: () => showQueueSheet(context, services, palette),
        ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 24,
    this.active = false,
    this.accent = WaveColors.musicRed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.84,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedSwitcher(
            duration: WaveMotion.fast,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey('$icon$active'),
              size: size,
              color: active
                  ? accent
                  : WaveColors.textPrimary.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleGlyph extends StatelessWidget {
  const _CircleGlyph({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: WaveColors.textPrimary),
        ),
      ),
    );
  }
}

/// The "…" menu, as a native Cupertino action sheet.
Future<void> showTrackActions(
  BuildContext context,
  Track track,
  WaveServices services,
) {
  final liked = services.favorites.contains(track);

  // The sheet pops itself once the callback returns, so anything pushed from
  // inside one is immediately popped back off. Navigation is deferred a frame.
  void afterSheet(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => action());

  return showGlassActionSheet<void>(
    context: context,
    title: track.title,
    message: track.artist,
    cancelLabel: 'Отмена',
    settings: appleMusicGlass(alpha: 0.94),
    actions: [
      GlassActionSheetAction(
        label: liked ? 'Убрать из медиатеки' : 'В медиатеку',
        icon: Icon(liked ? CupertinoIcons.heart_slash : CupertinoIcons.heart),
        onPressed: () => services.favorites.toggle(track),
      ),
      if (track.album.isNotEmpty)
        GlassActionSheetAction(
          label: 'Показать альбом',
          icon: const Icon(CupertinoIcons.square_stack),
          onPressed: () => afterSheet(() => openAlbum(context, track)),
        ),
      GlassActionSheetAction(
        label: 'Показать исполнителя',
        icon: const Icon(CupertinoIcons.person),
        onPressed: () => afterSheet(() => openArtist(context, track)),
      ),
    ],
  );
}

/// Up-next, in a native-feeling detented sheet.
Future<void> showQueueSheet(
  BuildContext context,
  WaveServices services,
  WavePalette palette,
) {
  return GlassModalSheet.show<void>(
    context: context,
    halfSize: 0.55,
    initialState: GlassSheetState.half,
    builder: (_) => _QueueSheet(services: services, palette: palette),
  );
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
              child: Text('Далее · ${queue.length}', style: WaveText.section),
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
