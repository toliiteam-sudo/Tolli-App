import 'package:flutter/material.dart';

class AppTransitions {
  // Centralized motion timing & curve constants
  static const Duration pageDuration = Duration(milliseconds: 280);
  static const Duration pageReverseDuration = Duration(milliseconds: 240);
  static const Duration popupDuration = Duration(milliseconds: 200);
  static const Duration bottomSheetDuration = Duration(milliseconds: 250);
  static const Duration microDuration = Duration(milliseconds: 150);

  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Slide page transition (280ms duration with smooth cubic easing)
  static Route<T> slidePageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: pageDuration,
      reverseTransitionDuration: pageReverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(0.08, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: defaultCurve));

        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Custom smooth modal dialog (200ms scale + fade transition)
  static Future<T?> showSmoothModal<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'ModalDismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: popupDuration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return child;
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: defaultCurve);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
    );
  }

  /// Custom smooth bottom sheet (250ms slide + fade transition)
  static Future<T?> showSmoothBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => AnimatedPadding(
        duration: microDuration,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: child,
      ),
    );
  }
}
