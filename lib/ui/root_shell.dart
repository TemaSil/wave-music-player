import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/wave_scope.dart';
import '../core/wave_theme.dart';
import 'screens/discover_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/aurora_background.dart';
import 'widgets/mini_player.dart';

/// The app frame: aurora background, swipeable tabs, and the glass tab bar
/// carrying the mini player as its bottom accessory.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _tabs = [
    GlassTab(icon: Icon(CupertinoIcons.waveform), label: 'Discover'),
    GlassTab(icon: Icon(CupertinoIcons.search), label: 'Search'),
    GlassTab(icon: Icon(CupertinoIcons.heart_fill), label: 'Library'),
  ];

  final PageController _pages = PageController();

  /// One controller per tab, so the tab bar can react to the scroll position
  /// of whichever tab is actually on screen.
  final List<ScrollController> _scrollControllers = List.generate(
    3,
    (_) => ScrollController(),
  );

  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _index) {
      // Re-tapping the active tab scrolls it back to the top, like iOS.
      final controller = _scrollControllers[index];
      if (controller.hasClients) {
        controller.animateTo(
          0,
          duration: WaveMotion.medium,
          curve: WaveMotion.emphasized,
        );
      }
      return;
    }
    _pages.animateToPage(
      index,
      duration: WaveMotion.medium,
      curve: WaveMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = WaveScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([services.player, services.ambience]),
      builder: (context, _) {
        final player = services.player;
        final palette = services.ambience.value;

        return GlassScaffold(
          backgroundColor: WaveColors.abyss,
          statusBarStyle: GlassStatusBarStyle.light,
          background: AuroraBackground(
            palette: palette,
            energy: player.isPlaying ? 1 : 0,
          ),
          bottomBar: GlassTabBar.bottom(
            tabs: _tabs,
            selectedIndex: _index,
            onTabSelected: _selectTab,
            scrollController: _scrollControllers[_index],
            selectedIconColor: palette.primary,
            selectedLabelColor: palette.primary,
            indicatorColor: palette.primary.withValues(alpha: 0.30),
            bottomAccessory: MiniPlayer(player: player, palette: palette),
            bottomAccessoryEnabled: player.hasTrack,
            bottomAccessoryHeight: MiniPlayer.height,
          ),
          bodyOverlays: [
            if (player.error != null)
              _ErrorBanner(
                message: player.error!,
                onDismiss: player.clearError,
              ),
          ],
          body: SafeArea(
            bottom: false,
            child: PageView(
              controller: _pages,
              onPageChanged: (index) => setState(() => _index = index),
              children: [
                DiscoverScreen(scrollController: _scrollControllers[0]),
                SearchScreen(scrollController: _scrollControllers[1]),
                LibraryScreen(scrollController: _scrollControllers[2]),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Transient glass banner for playback failures.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 8,
      child: GestureDetector(
        onTap: onDismiss,
        child: GlassContainer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 18,
                color: WaveColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: WaveText.caption)),
              const Icon(
                CupertinoIcons.xmark,
                size: 14,
                color: WaveColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
