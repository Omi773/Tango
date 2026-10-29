import 'package:flutter/material.dart';
import 'package:tango/theme/app_theme.dart';
import 'package:tango/theme/app_tokens.dart';
import 'package:tango/utils/desktop_platform.dart';

/// Rhythm's look: big rounded corners, pill navigation, stadium chips,
/// thick sliders and grouped list items.
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

    final tokens = (isDesktopPlatform ? AppTokens.desktop : AppTokens.standard)
        .copyWith(
          radiusCover: 20,
          radiusControl: 20,
          radiusCard: radiusLg,
          radiusSheet: radiusXl,
        );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        ...base.extensions.values.where((e) => e is! AppTokens),
        tokens,
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