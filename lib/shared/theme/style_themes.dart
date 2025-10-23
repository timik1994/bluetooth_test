import 'package:flutter/material.dart';
import 'theme_styles.dart';

class StyleThemes {
  // 1. Классический стиль - традиционный синий с белым текстом
  static AppBarTheme getClassicAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 4,
      backgroundColor: isDark ? Colors.blue.shade800 : Colors.blue,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static BottomNavigationBarThemeData getClassicBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      selectedItemColor: Colors.blue,
      unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      elevation: 8,
    );
  }

  // 2. Океанский градиент - морская тема с волнами
  static AppBarTheme getGradientAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
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
    );
  }

  static BottomNavigationBarThemeData getGradientBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      selectedItemColor: Colors.cyan,
      unselectedItemColor: Colors.white70,
      elevation: 0,
    );
  }

  // 3. Стеклянный морфизм - современный размытый стеклянный эффект
  static AppBarTheme getGlassAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 21,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  static BottomNavigationBarThemeData getGlassBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      selectedItemColor: isDark ? Colors.lightBlueAccent : Colors.indigo,
      unselectedItemColor: isDark ? Colors.grey.shade300 : Colors.grey.shade500,
      elevation: 0,
    );
  }

  // 4. Киберпанк неон - футуристический стиль с яркими неоновыми цветами
  static AppBarTheme getNeonAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: isDark ? Colors.black : Colors.grey.shade900,
      foregroundColor: Colors.pinkAccent,
      titleTextStyle: const TextStyle(
        color: Colors.pinkAccent,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            color: Colors.pinkAccent,
            blurRadius: 15,
          ),
          Shadow(
            color: Colors.purpleAccent,
            blurRadius: 25,
          ),
        ],
      ),
    );
  }

  static BottomNavigationBarThemeData getNeonBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? Colors.black : Colors.grey.shade900,
      selectedItemColor: Colors.pinkAccent,
      unselectedItemColor: Colors.purple.shade300,
      elevation: 0,
    );
  }

  // 5. Material You - современный адаптивный дизайн Google
  static AppBarTheme getMaterialAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
    );
  }

  static BottomNavigationBarThemeData getMaterialBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      selectedItemColor: isDark ? Colors.deepPurpleAccent : Colors.deepPurple,
      unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      elevation: 0,
    );
  }

  // 6. Готический стиль - темная элегантная тема с красными акцентами
  static AppBarTheme getDarkAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 6,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            color: Colors.red,
            blurRadius: 8,
            offset: Offset(2, 2),
          ),
        ],
      ),
    );
  }

  static BottomNavigationBarThemeData getDarkBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.black,
      selectedItemColor: Colors.redAccent,
      unselectedItemColor: Colors.grey.shade700,
      elevation: 8,
    );
  }

  // 7. Карнавал - веселый радужный стиль с множеством цветов
  static AppBarTheme getColorfulAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
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
    );
  }

  static BottomNavigationBarThemeData getColorfulBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      selectedItemColor: Colors.yellow,
      unselectedItemColor: Colors.white60,
      elevation: 0,
    );
  }

  // 8. Японский минимализм - чистый и элегантный стиль
  static AppBarTheme getMinimalAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w300,
        letterSpacing: 3.0,
      ),
    );
  }

  static BottomNavigationBarThemeData getMinimalBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      selectedItemColor: isDark ? Colors.white : Colors.black87,
      unselectedItemColor: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
      elevation: 0,
    );
  }

  // 9. Банковский стиль - строгий и надежный корпоративный дизайн
  static AppBarTheme getCorporateAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 4,
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  static BottomNavigationBarThemeData getCorporateBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      selectedItemColor: isDark ? Colors.amber : Colors.amber.shade700,
      unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      elevation: 4,
    );
  }

  // 10. Художественный стиль - креативный дизайн с необычными эффектами
  static AppBarTheme getCreativeAppBarTheme(bool isDark) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 25,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
        shadows: [
          Shadow(
            color: isDark ? Colors.purple : Colors.purple.shade300,
            blurRadius: 6,
            offset: const Offset(1, 1),
          ),
          Shadow(
            color: isDark ? Colors.orange : Colors.orange.shade300,
            blurRadius: 12,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
    );
  }

  static BottomNavigationBarThemeData getCreativeBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      selectedItemColor: isDark ? Colors.purpleAccent : Colors.purple,
      unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      elevation: 0,
    );
  }

  // Методы для получения стилей по enum
  static AppBarTheme getAppBarTheme(AppBarStyle style, bool isDark) {
    switch (style) {
      case AppBarStyle.classic:
        return getClassicAppBarTheme(isDark);
      case AppBarStyle.gradient:
        return getGradientAppBarTheme(isDark);
      case AppBarStyle.glass:
        return getGlassAppBarTheme(isDark);
      case AppBarStyle.neon:
        return getNeonAppBarTheme(isDark);
      case AppBarStyle.material:
        return getMaterialAppBarTheme(isDark);
      case AppBarStyle.dark:
        return getDarkAppBarTheme(isDark);
      case AppBarStyle.colorful:
        return getColorfulAppBarTheme(isDark);
      case AppBarStyle.minimal:
        return getMinimalAppBarTheme(isDark);
      case AppBarStyle.corporate:
        return getCorporateAppBarTheme(isDark);
      case AppBarStyle.creative:
        return getCreativeAppBarTheme(isDark);
    }
  }

  static BottomNavigationBarThemeData getBottomNavTheme(BottomNavStyle style, bool isDark) {
    switch (style) {
      case BottomNavStyle.classic:
        return getClassicBottomNavTheme(isDark);
      case BottomNavStyle.floating:
        return getGradientBottomNavTheme(isDark);
      case BottomNavStyle.glass:
        return getGlassBottomNavTheme(isDark);
      case BottomNavStyle.neon:
        return getNeonBottomNavTheme(isDark);
      case BottomNavStyle.material:
        return getMaterialBottomNavTheme(isDark);
      case BottomNavStyle.dark:
        return getDarkBottomNavTheme(isDark);
      case BottomNavStyle.colorful:
        return getColorfulBottomNavTheme(isDark);
      case BottomNavStyle.minimal:
        return getMinimalBottomNavTheme(isDark);
      case BottomNavStyle.corporate:
        return getCorporateBottomNavTheme(isDark);
      case BottomNavStyle.creative:
        return getCreativeBottomNavTheme(isDark);
    }
  }
}
