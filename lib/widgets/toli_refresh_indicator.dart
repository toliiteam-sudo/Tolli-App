import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// TOLII Custom Scroll Behavior to eliminate default Android overscroll glow/stretch.
class ToliScrollBehavior extends ScrollBehavior {
  const ToliScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }
}

/// TOLII Custom Pull-To-Refresh Widget.
/// Displays a small, clean, circular #063E9E indicator on a light background
/// without any Android default overscroll stretch or glow.
class ToliRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;

  const ToliRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const ToliScrollBehavior(),
      child: RefreshIndicator(
        color: AppColors.primary, // #063E9E
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        displacement: displacement,
        edgeOffset: 0.0,
        onRefresh: () async {
          try {
            await onRefresh();
          } catch (e) {
            // Gracefully handle errors so UI never crashes or gets stuck
          }
        },
        child: child,
      ),
    );
  }
}
