import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../shared/theme/theme_styles.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool isDark;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currentStyle = ThemeStyleManager.currentAppBarStyle;
    
    switch (currentStyle) {
      case AppBarStyle.gradient:
        return _buildGradientAppBar();
      case AppBarStyle.glass:
        return _buildGlassAppBar();
      case AppBarStyle.colorful:
        return _buildColorfulAppBar();
      default:
        return AppBar(
          title: Text(title),
          actions: actions,
        );
    }
  }

  Widget _buildGradientAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade300,
            Colors.blue.shade400,
            Colors.indigo.shade500,
            Colors.deepPurple.shade600,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        actions: actions,
      ),
    );
  }

  Widget _buildGlassAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: isDark 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: actions,
          ),
        ),
      ),
    );
  }

  Widget _buildColorfulAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade400,
            Colors.orange.shade400,
            Colors.yellow.shade400,
            Colors.green.shade400,
            Colors.blue.shade400,
            Colors.purple.shade400,
          ],
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
              Shadow(
                color: Colors.yellow,
                blurRadius: 8,
                offset: Offset(-1, -1),
              ),
            ],
          ),
        ),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
