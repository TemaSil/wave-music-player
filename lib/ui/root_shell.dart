import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/wave_scope.dart';
import '../core/wave_theme.dart';
import 'screens/discover_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_sheet.dart';
import 'widgets/aurora_background.dart';
import 'widgets/mini_player.dart';

/// The app frame, laid out the way Apple Music lays its own out.
///
/// The shape of this comes from the Apple Music reference demo that ships with
/// `liquid_glass_widgets`: a fixed header that fades out over the first 30
/// logical pixels of scroll, a searchable glass tab bar that spring-collapses
/// once the content has scrolled past a threshold, and the play pill riding in
/// the bar's `bottomAccessory` slot.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  /// Scroll offset past which the bar collapses. Apple Music uses a low
  /// threshold so the bar reacts almost immediately.
  static const _miniThreshold = 50.0;

  static const _barHeight = 64.0;
  static const _accessoryHeight = 50.0;
  static const _paddingH = 20.0;
  static const _paddingV = 16.0;
  static const _spacing = 8.0;

  static const _tabs = [
    GlassTab(
      label: 'Главное',
      icon: Icon(CupertinoIcons.house),
      activeIcon: Icon(CupertinoIcons.house_fill),
    ),
    GlassTab(
      label: 'Медиатека',
      icon: Icon(CupertinoIcons.music_albums),
      activeIcon: Icon(CupertinoIcons.music_albums_fill),
    ),
  ];

  final List<ScrollController> _scrollControllers = List.generate(
    2,
    (_) => ScrollController(),
  );
  final FocusNode _searchFocus = FocusNode();

  /// The search field lives in the tab bar, so the shell owns its text and
  /// hands the query down to the results screen.
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  int _index = 0;
  bool _mini = false;
  bool _searching = false;
  bool _searchFocused = false;

  ScrollController get _activeScroll => _scrollControllers[_index];

  @override
  void initState() {
    super.initState();
    for (final controller in _scrollControllers) {
      controller.addListener(_onScroll);
    }
    _searchFocus.addListener(
      () => setState(() => _searchFocused = _searchFocus.hasFocus),
    );
  }

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller
        ..removeListener(_onScroll)
        ..dispose();
    }
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = _activeScroll;
    final mini = controller.hasClients && controller.offset > _miniThreshold;
    if (mini == _mini) return;
    setState(() => _mini = mini);
  }

  /// Tapping the collapsed bar sends the active tab back to the top, which is
  /// what expands the bar again.
  void _expand() {
    final controller = _activeScroll;
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
      );
    }
    setState(() {
      _mini = false;
      _searching = false;
      _searchFocused = false;
    });
  }

  void _selectTab(int index) {
    if (index == _index && _mini) {
      _expand();
      return;
    }
    final controller = _scrollControllers[index];
    setState(() {
      _index = index;
      _searching = false;
      _mini = controller.hasClients && controller.offset > _miniThreshold;
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = WaveScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        services.player,
        services.ambience,
        services.appearance,
      ]),
      builder: (context, _) {
        final player = services.player;
        final palette = services.ambience.value;
        final live = services.appearance.usesLiveColour;
        final accent = live ? palette.primary : WaveColors.musicRed;

        // Bar + its padding + the accessory + spacing + clearance, so the last
        // row of every list clears the floating chrome.
        final contentPad =
            _barHeight +
            _paddingV * 2 +
            _accessoryHeight +
            _spacing +
            8 +
            MediaQuery.viewPaddingOf(context).bottom;

        return GlassScaffold(
          backgroundColor: live ? WaveColors.abyss : WaveColors.appleBackground,
          statusBarStyle: GlassStatusBarStyle.light,
          settings: appleMusicGlass(alpha: 0.80),
          background: live
              ? AuroraBackground(
                  palette: palette,
                  energy: player.isPlaying ? 1 : 0,
                  animate: services.appearance.ambientMotion,
                )
              : const ColoredBox(color: WaveColors.appleBackground),
          topEdgeFade: true,
          bottomEdgeFade: true,
          topEdgeFadeExtent: 0,
          bottomEdgeFadeExtent: 0,
          resizeToAvoidBottomInset: false,

          // The iOS large-title pattern: a real header that fades away as the
          // content scrolls under it, rather than a title baked into the list.
          header: _searching ? null : _Header(title: _title, accent: accent),
          headerScrollController: _activeScroll,
          headerFadeDistance: 30,

          bodyOverlays: [
            if (player.error != null)
              _ErrorBanner(
                message: player.error!,
                onDismiss: player.clearError,
              ),
          ],

          body: AnimatedSwitcher(
            duration: WaveMotion.medium,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _searching
                ? SearchScreen(
                    key: const ValueKey('search'),
                    query: _query,
                    contentPadding: contentPad,
                    onSuggestion: (value) {
                      _searchController.text = value;
                      setState(() => _query = value);
                    },
                  )
                : switch (_index) {
                    1 => LibraryScreen(
                      key: const ValueKey('library'),
                      scrollController: _scrollControllers[1],
                      contentPadding: contentPad,
                    ),
                    _ => DiscoverScreen(
                      key: const ValueKey('discover'),
                      scrollController: _scrollControllers[0],
                      contentPadding: contentPad,
                    ),
                  },
          ),

          bottomBar: GlassTabBar.searchable(
            tabs: _tabs,
            selectedIndex: _index,
            onTabSelected: _selectTab,
            // Collapsing on scroll and collapsing for search are the same
            // animation in iOS 26; the bar takes one flag for both.
            isSearchActive: _mini || _searching,
            bottomAccessoryPlacement: (_mini && !_searching)
                ? GlassTabBarAccessoryPlacement.inline
                : GlassTabBarAccessoryPlacement.expanded,
            bottomAccessory: MiniPlayer(
              player: player,
              palette: palette,
              accent: accent,
              onExpandBar: _expand,
            ),
            bottomAccessoryHeight: _accessoryHeight,
            bottomAccessoryEnabled: player.hasTrack && !_searchFocused,
            barHeight: _barHeight,
            searchBarHeight: _accessoryHeight,
            horizontalPadding: _paddingH,
            verticalPadding: _paddingV,
            spacing: _spacing,
            iconSize: 28,
            labelFontSize: 10,
            iconLabelSpacing: 0,
            quality: GlassQuality.premium,
            settings: appleMusicGlass(alpha: 0.67),
            selectedIconColor: accent,
            selectedLabelColor: accent,
            unselectedIconColor: WaveColors.textPrimary.withValues(alpha: 0.9),
            indicatorColor: WaveColors.textPrimary.withValues(alpha: 0.20),
            searchConfig: GlassSearchBarConfig(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (value) => setState(() => _query = value),
              autoFocusOnExpand: false,
              showsCancelButton: true,
              expandWhenActive: !_mini || _searching,
              hintText: 'Исполнители, треки, альбомы',
              onSearchToggle: (active) {
                if (active) {
                  setState(() => _searching = true);
                } else {
                  _searchController.clear();
                  setState(() {
                    _searching = false;
                    _searchFocused = false;
                    _query = '';
                  });
                  if (_mini) _expand();
                }
              },
              onSearchFocusChanged: (focused) =>
                  setState(() => _searchFocused = focused),
              textInputAction: TextInputAction.search,
              // While the bar is collapsed the search capsule shrinks to a
              // single glyph; show the active tab's icon there, as iOS does.
              collapsedLogoBuilder: (context) {
                final tab = _tabs[_index];
                final icon = tab.activeIcon ?? tab.icon;
                if (icon is Icon) {
                  return Center(
                    child: Icon(
                      icon.icon,
                      size: 28,
                      color: _mini && !_searching
                          ? accent
                          : WaveColors.textPrimary.withValues(alpha: 0.9),
                    ),
                  );
                }
                return icon ?? const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );
  }

  String get _title => switch (_index) {
    1 => 'Медиатека',
    _ => 'Слушать',
  };
}

/// Large title plus the settings button, in Apple Music's proportions.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.accent});

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
      child: Row(
        children: [
          Text(title, style: WaveText.largeTitle.copyWith(fontSize: 34)),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Настройки',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showSettingsSheet(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.22),
                ),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 19,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
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
          settings: appleMusicGlass(),
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
