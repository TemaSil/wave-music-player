import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/appearance.dart';
import '../../core/wave_scope.dart';
import '../../core/wave_theme.dart';
import '../../data/music_api.dart';
import '../../data/track.dart';

/// Opens appearance settings in a glass sheet.
Future<void> showSettingsSheet(BuildContext context) {
  return GlassModalSheet.show<void>(
    context: context,
    halfSize: 0.62,
    initialState: GlassSheetState.half,
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final services = WaveScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([services.appearance, services.ambience]),
      builder: (context, _) {
        final appearance = services.appearance;
        final live = appearance.usesLiveColour;
        final accent = live
            ? services.ambience.value.primary
            : WaveColors.musicRed;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Оформление', style: WaveText.title),
            const SizedBox(height: 14),

            for (final skin in WaveSkin.values) ...[
              _SkinRow(
                skin: skin,
                selected: appearance.skin == skin,
                accent: accent,
                onTap: () => appearance.setSkin(skin),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 10),
            _SettingRow(
              title: 'Движение фона',
              subtitle: live
                  ? 'Градиент медленно дрейфует'
                  : 'Заработает вместе с живыми цветами',
              child: GlassSwitch(
                value: appearance.ambientMotion,
                onChanged: appearance.setAmbientMotion,
                activeColor: accent,
              ),
            ),

            const SizedBox(height: 26),
            Text('Каталог', style: WaveText.title),
            const SizedBox(height: 14),
            if (kDemoMode)
              Text(
                'Сборка работает на встроенном офлайн-каталоге.',
                style: WaveText.caption,
              )
            else
              GlassSegmentedControl(
                segments: const [
                  GlassSegment(label: 'Apple / iTunes'),
                  GlassSegment(label: 'Deezer'),
                ],
                selectedIndex: services.music.activeId == MusicSourceId.itunes
                    ? 0
                    : 1,
                onSegmentSelected: (index) => services.music.activeId =
                    index == 0 ? MusicSourceId.itunes : MusicSourceId.deezer,
              ),

            const SizedBox(height: 26),
            Text(
              'Wave · превью по 30 секунд из публичных каталогов',
              style: WaveText.tiny,
            ),
          ],
        );
      },
    );
  }
}

/// One selectable skin, previewed by its own colours.
class _SkinRow extends StatelessWidget {
  const _SkinRow({
    required this.skin,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final WaveSkin skin;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = switch (skin) {
      WaveSkin.appleMusic => const [WaveColors.musicRed, Color(0xFFE2072C)],
      WaveSkin.aurora => const [WaveColors.violet, WaveColors.cyan],
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: WaveMotion.medium,
        curve: WaveMotion.emphasized,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? accent.withValues(alpha: 0.16)
              : WaveColors.appleCard.withValues(alpha: 0.55),
          border: Border.all(
            color: selected ? accent : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: swatch,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(skin.label, style: WaveText.body),
                  const SizedBox(height: 2),
                  Text(skin.description, style: WaveText.caption),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: WaveMotion.fast,
              child: Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: accent,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: WaveText.body),
              const SizedBox(height: 2),
              Text(subtitle, style: WaveText.caption),
            ],
          ),
        ),
        const SizedBox(width: 12),
        child,
      ],
    );
  }
}
