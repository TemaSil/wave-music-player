import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../../core/wave_theme.dart';

/// Network artwork with a calm placeholder and a graceful failure state.
///
/// Album art loads over the network on every row, so the placeholder must not
/// flash white or jump — it fades in over a neutral tile instead.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 22,
  });

  final String url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder(showIcon: true);
    // Demo-mode artwork ships in the bundle rather than over the network.
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(showIcon: true),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: WaveMotion.fast,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _placeholder(showIcon: true),
    );
  }

  Widget _placeholder({bool showIcon = false}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17172A), Color(0xFF0E0E1A)],
        ),
      ),
      child: showIcon
          ? Center(
              child: Icon(
                CupertinoIcons.music_note,
                size: iconSize,
                color: WaveColors.textTertiary,
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
