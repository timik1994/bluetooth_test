import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../shared/theme/theme_styles.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;
  final bool isDark;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currentStyle = ThemeStyleManager.currentBottomNavStyle;
    
    switch (currentStyle) {
      case BottomNavStyle.floating:
        return _buildFloatingBottomNav();
      case BottomNavStyle.glass:
        return _buildGlassBottomNav();
      case BottomNavStyle.colorful:
        return _buildColorfulBottomNav();
      default:
        return BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          items: items,
        );
    }
  }

  Widget _buildFloatingBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          items: items,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.cyan,
          unselectedItemColor: Colors.white70,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildGlassBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            border: Border(
              top: BorderSide(
                color: isDark 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
            backgroundColor: Colors.transparent,
            selectedItemColor: isDark ? Colors.cyan : Colors.blue,
            unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildColorfulBottomNav() {
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
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: items,
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
