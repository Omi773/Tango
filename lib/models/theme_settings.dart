import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tango/utils/desktop_platform.dart';

const String kThemeModeKey = 'theme_mode';
const String kUseDynamicColorKey = 'use_dynamic_color';
const String kSeedColorKey = 'seed_color';
const String kUseAmoledKey = 'use_amoled';
const String kThemeStyleKey = 'theme_style';
const String kTangoAccentKey = 'tango_accent';
const String kUseSystemFontKey = 'use_system_font';
const String kCustomFontIdKey = 'custom_font_id';
const String kCustomFontNameKey = 'custom_font_name';
const String kLyricsTextScaleKey = 'lyrics_text_scale';

double normalizeLyricsTextScale(num? value) =>
    value != null && value.isFinite ? value.toDouble().clamp(0.8, 1.4) : 1.0;
const String kTangoGlassClarityKey = 'tango_glass_clarity';
const String kTangoGlassOutlinesKey = 'tango_glass_outlines';
const double kDefaultTangoGlassClarity = 0.75;

double normalizeTangoGlassClarity(num? value) =>
    value != null && value.isFinite
    ? value.toDouble().clamp(0.0, 1.0)
    : kDefaultTangoGlassClarity;

enum AppThemeStyle { material, tango }

enum TangoAccent { red, orange, green, teal, blue, purple, pink }

TangoAccent tangoAccentFromString(String? value) =>
    TangoAccent.values.firstWhere(
      (accent) => accent.name == value,
      orElse: () => TangoAccent.red,
    );

/// Style used until the person picks one: Tango on macOS, Material on
/// Windows, Linux and mobile.
AppThemeStyle defaultAppThemeStyle() =>
    isDesktopPlatform && defaultTargetPlatform == TargetPlatform.macOS
    ? AppThemeStyle.tango
    : AppThemeStyle.material;

AppThemeStyle themeStyleFromString(String? value) => AppThemeStyle.values
    .firstWhere((style) => style.name == value, orElse: defaultAppThemeStyle);

/// Default Spotify green color for fallback
const int kDefaultSeedColor = 0xFF1DB954;

class ThemeSettings {
  final ThemeMode themeMode;
  final bool useDynamicColor;
  final int seedColorValue;
  final bool useAmoled;
  final AppThemeStyle style;
  final TangoAccent tangoAccent;
  final bool useSystemFont;
  final String customFontId;
  final String customFontName;
  final double lyricsTextScale;
  final double tangoGlassClarity;
  final bool tangoGlassOutlines;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = true,
    this.seedColorValue = kDefaultSeedColor,
    this.useAmoled = false,
    this.style = AppThemeStyle.material,
    this.tangoAccent = TangoAccent.red,
    this.useSystemFont = false,
    this.customFontId = '',
    this.customFontName = '',
    this.lyricsTextScale = 1,
    this.tangoGlassClarity = kDefaultTangoGlassClarity,
    this.tangoGlassOutlines = true,
  });

  Color get seedColor => Color(seedColorValue);

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    int? seedColorValue,
    bool? useAmoled,
    AppThemeStyle? style,
    TangoAccent? tangoAccent,
    bool? useSystemFont,
    String? customFontId,
    String? customFontName,
    double? lyricsTextScale,
    double? tangoGlassClarity,
    bool? tangoGlassOutlines,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      useAmoled: useAmoled ?? this.useAmoled,
      style: style ?? this.style,
      tangoAccent: tangoAccent ?? this.tangoAccent,
      useSystemFont: useSystemFont ?? this.useSystemFont,
      customFontId: customFontId ?? this.customFontId,
      customFontName: customFontName ?? this.customFontName,
      lyricsTextScale: normalizeLyricsTextScale(
        lyricsTextScale ?? this.lyricsTextScale,
      ),
      tangoGlassClarity: normalizeTangoGlassClarity(
        tangoGlassClarity ?? this.tangoGlassClarity,
      ),
      tangoGlassOutlines: tangoGlassOutlines ?? this.tangoGlassOutlines,
    );
  }

  Map<String, dynamic> toJson() => {
    kThemeModeKey: themeMode.name,
    kUseDynamicColorKey: useDynamicColor,
    kSeedColorKey: seedColorValue,
    kUseAmoledKey: useAmoled,
    kThemeStyleKey: style.name,
    kTangoAccentKey: tangoAccent.name,
    kUseSystemFontKey: useSystemFont,
    kCustomFontIdKey: customFontId,
    kCustomFontNameKey: customFontName,
    kLyricsTextScaleKey: lyricsTextScale,
    kTangoGlassClarityKey: tangoGlassClarity,
    kTangoGlassOutlinesKey: tangoGlassOutlines,
  };

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      themeMode: themeModeFromString(json[kThemeModeKey] as String?),
      useDynamicColor: json[kUseDynamicColorKey] as bool? ?? true,
      seedColorValue: json[kSeedColorKey] as int? ?? kDefaultSeedColor,
      useAmoled: json[kUseAmoledKey] as bool? ?? false,
      style: themeStyleFromString(json[kThemeStyleKey] as String?),
      tangoAccent: tangoAccentFromString(json[kTangoAccentKey] as String?),
      useSystemFont: json[kUseSystemFontKey] as bool? ?? false,
      customFontId: json[kCustomFontIdKey] as String? ?? '',
      customFontName: json[kCustomFontNameKey] as String? ?? '',
      lyricsTextScale: normalizeLyricsTextScale(
        json[kLyricsTextScaleKey] as num?,
      ),
      tangoGlassClarity: normalizeTangoGlassClarity(
        json[kTangoGlassClarityKey] as num?,
      ),
      tangoGlassOutlines: json[kTangoGlassOutlinesKey] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeSettings &&
        other.themeMode == themeMode &&
        other.useDynamicColor == useDynamicColor &&
        other.seedColorValue == seedColorValue &&
        other.useAmoled == useAmoled &&
        other.style == style &&
        other.tangoAccent == tangoAccent &&
        other.useSystemFont == useSystemFont &&
        other.customFontId == customFontId &&
        other.customFontName == customFontName &&
        other.lyricsTextScale == lyricsTextScale &&
        other.tangoGlassClarity == tangoGlassClarity &&
        other.tangoGlassOutlines == tangoGlassOutlines;
  }

  @override
  int get hashCode =>
      themeMode.hashCode ^
      useDynamicColor.hashCode ^
      seedColorValue.hashCode ^
      useAmoled.hashCode ^
      style.hashCode ^
      tangoAccent.hashCode ^
      useSystemFont.hashCode ^
      customFontId.hashCode ^
      customFontName.hashCode ^
      lyricsTextScale.hashCode ^
      tangoGlassClarity.hashCode ^
      tangoGlassOutlines.hashCode;
}

ThemeMode themeModeFromString(String? value) {
  if (value == null) return ThemeMode.system;
  return ThemeMode.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ThemeMode.system,
  );
}
