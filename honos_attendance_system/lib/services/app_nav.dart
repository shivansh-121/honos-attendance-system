import 'package:flutter/material.dart';

/// A custom page route that uses a smooth fade + slight upward slide transition.
/// Use [AppNav.push] instead of [Navigator.push] throughout the app.
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeSlideRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Outgoing screen fades slightly
            final fadeOut = Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
            );

            // Incoming screen fades in and slides up slightly
            final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );
            final slideIn = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

            return FadeTransition(
              opacity: fadeOut,
              child: FadeTransition(
                opacity: fadeIn,
                child: SlideTransition(
                  position: slideIn,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Convenience wrapper for navigation throughout the app.
class AppNav {
  /// Push a new screen with a smooth fade-slide transition.
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).push<T>(FadeSlideRoute(page: screen));
  }

  /// Replace the current screen with a smooth transition.
  static Future<T?> replace<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).pushReplacement<T, dynamic>(
      FadeSlideRoute(page: screen),
    );
  }

  /// Push and remove all previous routes (e.g. after login).
  static Future<T?> pushAndClearStack<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      FadeSlideRoute(page: screen),
      (route) => false,
    );
  }
}
