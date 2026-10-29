import 'package:flutter/material.dart';
import 'package:tango/theme/app_theme.dart';
import 'package:tango/theme/app_tokens.dart';
import 'package:tango/utils/desktop_platform.dart';

/// Marker that tells widgets the Rhythm style is active.
/// Use `context.isRhythm` (defined next to `context.isTango`).
@immutable
class RhythmStyle extends ThemeExtension<RhythmStyle> {
  const RhythmStyle();

  @override
  RhythmStyle copyWith() => this;

  @override
  RhythmStyle lerp(ThemeExtension<RhythmStyle>? other, double t) => this;
}

/// Rhythm's look on top of Tango's Material 3 Expressive theme: big rounded
/// corners, pill navigation and tabs, stadium chips and search, thick
/// sliders, rounded sheets, menus and snack bars, larger artwork and
/// larger page titles.
class RhythmTheme {
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 28;

  /// Rounded ends, tight middle (Rhythm's grouped settings and lists).
  static BorderRadius grouped(int index, int count) {
    const big = Radius.circular(radiusLg);
    const small = Radius.circular(radiusXs);
    if (count <= 1) return BorderRadius.circular(radiusLg);
    if (index == 0) {
      return const BorderRadius.only(
        topLeft: big,
        topRight: big,
        bottomLeft: small,
        bottomRight: small,
      );
    }
    if (index == count - 1) {
      return const BorderRadius.only(
        topLeft: small,
        topRight: small,
        bottomLeft: big,
        bottomRight: big,
      );
    }
    return BorderRadius.circular(radiusXs);
  }

  static ThemeData light({
    ColorScheme? dynamicScheme,
    Color? seedColor,
    bool useSystemFont = false,
    String? fontFamily,
  }) => _apply(
    AppTheme.light(
      dynamicScheme: dynamicScheme,
      seedColor: seedColor,
      useSystemFont: useSystemFont,
      fontFamily: fontFamily,
    ),
  );

  static ThemeData dark({
    ColorScheme? dynamicScheme,
    Color? seedColor,
    bool isAmoled = false,
    bool useSystemFont = false,
    String? fontFamily,
  }) => _apply(
    AppTheme.dark(
      dynamicScheme: dynamicScheme,
      seedColor: seedColor,
      isAmoled: isAmoled,
      useSystemFont: useSystemFont,
      fontFamily: fontFamily,
    ),
  );

  static ThemeData _apply(ThemeData base) {
    final scheme = base.colorScheme;
    final text = base.textTheme;

    var tokens = (isDesktopPlatform ? AppTokens.desktop : AppTokens.standard)
        .copyWith(
          radiusThumb: 12,
          radiusCover: 20,
          radiusControl: 20,
          radiusCard: radiusLg,
          radiusSheet: radiusXl,
          lyricsLineHeight: 1.4,
          lyricsLinePaddingV: 14,
        );
    if (!isDesktopPlatform) {
      // Larger artwork and page titles, like Rhythm's phone layouts.
      tokens = tokens.copyWith(
        coverMini: 52,
        coverCompact: 52,
        coverList: 60,
        headerExpandedHeight: 140,
        headerExpandedTitleSize: 34,
      );
    }

    return base.copyWith(
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is AppTokens) tokens else extension,
        const RhythmStyle(),
      ],
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.secondaryContainer,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(100),
        ),
        labelColor: scheme.onSecondaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 10,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        overlayShape: SliderComponentShape.noOverlay,
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check)
              : null,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
    );
  }
}
