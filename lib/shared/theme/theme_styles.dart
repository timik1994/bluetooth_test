enum AppBarStyle {
  classic,        // Классический синий
  gradient,       // Градиентный
  glass,          // Стеклянный эффект
  neon,           // Неоновый
  material,       // Material Design 3
  dark,           // Темный
  colorful,       // Яркий разноцветный
  minimal,        // Минималистичный
  corporate,      // Корпоративный
  creative,       // Креативный
}

enum BottomNavStyle {
  classic,        // Классический
  floating,       // Плавающий
  glass,          // Стеклянный
  neon,           // Неоновый
  material,       // Material Design 3
  dark,           // Темный
  colorful,       // Яркий
  minimal,        // Минималистичный
  corporate,      // Корпоративный
  creative,       // Креативный
}

class ThemeStyleManager {
  static AppBarStyle _currentAppBarStyle = AppBarStyle.classic;
  static BottomNavStyle _currentBottomNavStyle = BottomNavStyle.classic;

  static AppBarStyle get currentAppBarStyle => _currentAppBarStyle;
  static BottomNavStyle get currentBottomNavStyle => _currentBottomNavStyle;

  static void setAppBarStyle(AppBarStyle style) {
    _currentAppBarStyle = style;
  }

  static void setBottomNavStyle(BottomNavStyle style) {
    _currentBottomNavStyle = style;
  }

  static void setBothStyles(AppBarStyle appBarStyle, BottomNavStyle bottomNavStyle) {
    _currentAppBarStyle = appBarStyle;
    _currentBottomNavStyle = bottomNavStyle;
  }
}
