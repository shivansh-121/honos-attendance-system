import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../app_theme.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: child.key == const ValueKey('moon') 
              ? Tween<double>(begin: -0.5, end: 0).animate(anim) 
              : Tween<double>(begin: 0.5, end: 0).animate(anim),
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: isDark
            ? Icon(Icons.dark_mode, key: const ValueKey('moon'), color: context.colors.primary)
            : Icon(Icons.light_mode, key: const ValueKey('sun'), color: context.colors.yellow),
      ),
      onPressed: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      tooltip: 'Toggle Theme',
    );
  }
}
