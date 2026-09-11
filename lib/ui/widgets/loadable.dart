import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/wave_theme.dart';

/// The three states every catalogue request can be in.
sealed class Loadable<T> {
  const Loadable();
}

class Loading<T> extends Loadable<T> {
  const Loading();
}

class Success<T> extends Loadable<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Loadable<T> {
  const Failure(this.message);
  final String message;
}

/// Cross-fades between the loading, error and content states of a [Loadable].
class LoadableView<T> extends StatelessWidget {
  const LoadableView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.accent = WaveColors.violet,
    this.loadingHeight = 180,
  });

  final Loadable<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback onRetry;
  final Color accent;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: WaveMotion.medium,
      switchInCurve: WaveMotion.emphasized,
      child: switch (state) {
        Loading<T>() => SizedBox(
          key: const ValueKey('loading'),
          height: loadingHeight,
          child: Center(
            child: GlassProgressIndicator.circular(size: 28, color: accent),
          ),
        ),
        Failure<T>(:final message) => _ErrorState(
          key: const ValueKey('error'),
          message: message,
          onRetry: onRetry,
        ),
        Success<T>(:final value) => KeyedSubtree(
          key: const ValueKey('data'),
          child: builder(context, value),
        ),
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.wifi_slash,
              size: 28,
              color: WaveColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: WaveText.caption),
            const SizedBox(height: 16),
            GlassButton(
              icon: const Icon(CupertinoIcons.arrow_clockwise),
              onTap: onRetry,
              label: 'Ещё раз',
              width: 52,
              height: 40,
              iconSize: 18,
              shape: const LiquidRoundedSuperellipse(borderRadius: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a request succeeds but the catalogue had nothing to give.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: WaveColors.textTertiary),
          const SizedBox(height: 16),
          Text(title, style: WaveText.section, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: WaveText.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
