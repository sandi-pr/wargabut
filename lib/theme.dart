import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static MaterialScheme lightScheme() {
    return const MaterialScheme(
      brightness: Brightness.light,
      primary: Color(0xff06677f),
      surfaceTint: Color(0xff06677f),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffb7eaff),
      onPrimaryContainer: Color(0xff001f28),
      secondary: Color(0xff4c626a),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffcfe6f1),
      onSecondaryContainer: Color(0xff071e26),
      tertiary: Color(0xff5a5c7e),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffe0e0ff),
      onTertiaryContainer: Color(0xff171937),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff410002),
      background: Color(0xfff5fafd),
      onBackground: Color(0xff171c1f),
      surface: Color(0xfff5fafd),
      onSurface: Color(0xff171c1f),
      surfaceVariant: Color(0xffdbe4e8),
      onSurfaceVariant: Color(0xff40484c),
      outline: Color(0xff70787c),
      outlineVariant: Color(0xffbfc8cc),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c3134),
      inverseOnSurface: Color(0xffedf1f4),
      inversePrimary: Color(0xff88d1eb),
      primaryFixed: Color(0xffb7eaff),
      onPrimaryFixed: Color(0xff001f28),
      primaryFixedDim: Color(0xff88d1eb),
      onPrimaryFixedVariant: Color(0xff004e60),
      secondaryFixed: Color(0xffcfe6f1),
      onSecondaryFixed: Color(0xff071e26),
      secondaryFixedDim: Color(0xffb3cad4),
      onSecondaryFixedVariant: Color(0xff344a52),
      tertiaryFixed: Color(0xffe0e0ff),
      onTertiaryFixed: Color(0xff171937),
      tertiaryFixedDim: Color(0xffc3c3eb),
      onTertiaryFixedVariant: Color(0xff424465),
      surfaceDim: Color(0xffd6dbde),
      surfaceBright: Color(0xfff5fafd),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff4f7),
      surfaceContainer: Color(0xffeaeff1),
      surfaceContainerHigh: Color(0xffe4e9ec),
      surfaceContainerHighest: Color(0xffdee3e6),
    );
  }

  ThemeData light() {
    return theme(lightScheme().toColorScheme());
  }

  static MaterialScheme lightMediumContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.light,
      primary: Color(0xff00495b),
      surfaceTint: Color(0xff06677f),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff2e7e96),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff30464e),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff627881),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff3e4061),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff707295),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff8c0009),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffda342e),
      onErrorContainer: Color(0xffffffff),
      background: Color(0xfff5fafd),
      onBackground: Color(0xff171c1f),
      surface: Color(0xfff5fafd),
      onSurface: Color(0xff171c1f),
      surfaceVariant: Color(0xffdbe4e8),
      onSurfaceVariant: Color(0xff3c4448),
      outline: Color(0xff586064),
      outlineVariant: Color(0xff747c80),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c3134),
      inverseOnSurface: Color(0xffedf1f4),
      inversePrimary: Color(0xff88d1eb),
      primaryFixed: Color(0xff2e7e96),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff00647c),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff627881),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff495f68),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff707295),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff58597b),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffd6dbde),
      surfaceBright: Color(0xfff5fafd),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff4f7),
      surfaceContainer: Color(0xffeaeff1),
      surfaceContainerHigh: Color(0xffe4e9ec),
      surfaceContainerHighest: Color(0xffdee3e6),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme().toColorScheme());
  }

  static MaterialScheme lightHighContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.light,
      primary: Color(0xff002631),
      surfaceTint: Color(0xff06677f),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff00495b),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff0e252d),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff30464e),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff1d1f3e),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff3e4061),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff4e0002),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff8c0009),
      onErrorContainer: Color(0xffffffff),
      background: Color(0xfff5fafd),
      onBackground: Color(0xff171c1f),
      surface: Color(0xfff5fafd),
      onSurface: Color(0xff000000),
      surfaceVariant: Color(0xffdbe4e8),
      onSurfaceVariant: Color(0xff1d2528),
      outline: Color(0xff3c4448),
      outlineVariant: Color(0xff3c4448),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2c3134),
      inverseOnSurface: Color(0xffffffff),
      inversePrimary: Color(0xffd1f1ff),
      primaryFixed: Color(0xff00495b),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff00313e),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff30464e),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff1a3037),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff3e4061),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff282a49),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffd6dbde),
      surfaceBright: Color(0xfff5fafd),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff4f7),
      surfaceContainer: Color(0xffeaeff1),
      surfaceContainerHigh: Color(0xffe4e9ec),
      surfaceContainerHighest: Color(0xffdee3e6),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme().toColorScheme());
  }

  static MaterialScheme darkScheme() {
    return const MaterialScheme(
      brightness: Brightness.dark,
      primary: Color(0xff88d1eb),
      surfaceTint: Color(0xff88d1eb),
      onPrimary: Color(0xff003543),
      primaryContainer: Color(0xff004e60),
      onPrimaryContainer: Color(0xffb7eaff),
      secondary: Color(0xffb3cad4),
      onSecondary: Color(0xff1e333b),
      secondaryContainer: Color(0xff344a52),
      onSecondaryContainer: Color(0xffcfe6f1),
      tertiary: Color(0xffc3c3eb),
      onTertiary: Color(0xff2c2e4d),
      tertiaryContainer: Color(0xff424465),
      onTertiaryContainer: Color(0xffe0e0ff),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      background: Color(0xff0f1416),
      onBackground: Color(0xffdee3e6),
      surface: Color(0xff0f1416),
      onSurface: Color(0xffdee3e6),
      surfaceVariant: Color(0xff40484c),
      onSurfaceVariant: Color(0xffbfc8cc),
      outline: Color(0xff8a9296),
      outlineVariant: Color(0xff40484c),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdee3e6),
      inverseOnSurface: Color(0xff2c3134),
      inversePrimary: Color(0xff06677f),
      primaryFixed: Color(0xffb7eaff),
      onPrimaryFixed: Color(0xff001f28),
      primaryFixedDim: Color(0xff88d1eb),
      onPrimaryFixedVariant: Color(0xff004e60),
      secondaryFixed: Color(0xffcfe6f1),
      onSecondaryFixed: Color(0xff071e26),
      secondaryFixedDim: Color(0xffb3cad4),
      onSecondaryFixedVariant: Color(0xff344a52),
      tertiaryFixed: Color(0xffe0e0ff),
      onTertiaryFixed: Color(0xff171937),
      tertiaryFixedDim: Color(0xffc3c3eb),
      onTertiaryFixedVariant: Color(0xff424465),
      surfaceDim: Color(0xff0f1416),
      surfaceBright: Color(0xff353a3c),
      surfaceContainerLowest: Color(0xff0a0f11),
      surfaceContainerLow: Color(0xff171c1f),
      surfaceContainer: Color(0xff1b2023),
      surfaceContainerHigh: Color(0xff252b2d),
      surfaceContainerHighest: Color(0xff303638),
    );
  }

  ThemeData dark() {
    return theme(darkScheme().toColorScheme());
  }

  static MaterialScheme darkMediumContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.dark,
      primary: Color(0xff8cd5f0),
      surfaceTint: Color(0xff88d1eb),
      onPrimary: Color(0xff001921),
      primaryContainer: Color(0xff509ab3),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffb7ced9),
      onSecondary: Color(0xff021920),
      secondaryContainer: Color(0xff7e949e),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffc7c7ef),
      onTertiary: Color(0xff111331),
      tertiaryContainer: Color(0xff8d8eb3),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffbab1),
      onError: Color(0xff370001),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      background: Color(0xff0f1416),
      onBackground: Color(0xffdee3e6),
      surface: Color(0xff0f1416),
      onSurface: Color(0xfff7fbfe),
      surfaceVariant: Color(0xff40484c),
      onSurfaceVariant: Color(0xffc4ccd0),
      outline: Color(0xff9ca4a8),
      outlineVariant: Color(0xff7c8488),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdee3e6),
      inverseOnSurface: Color(0xff252b2d),
      inversePrimary: Color(0xff004f62),
      primaryFixed: Color(0xffb7eaff),
      onPrimaryFixed: Color(0xff00141a),
      primaryFixedDim: Color(0xff88d1eb),
      onPrimaryFixedVariant: Color(0xff003c4b),
      secondaryFixed: Color(0xffcfe6f1),
      onSecondaryFixed: Color(0xff00141a),
      secondaryFixedDim: Color(0xffb3cad4),
      onSecondaryFixedVariant: Color(0xff243941),
      tertiaryFixed: Color(0xffe0e0ff),
      onTertiaryFixed: Color(0xff0c0e2c),
      tertiaryFixedDim: Color(0xffc3c3eb),
      onTertiaryFixedVariant: Color(0xff323353),
      surfaceDim: Color(0xff0f1416),
      surfaceBright: Color(0xff353a3c),
      surfaceContainerLowest: Color(0xff0a0f11),
      surfaceContainerLow: Color(0xff171c1f),
      surfaceContainer: Color(0xff1b2023),
      surfaceContainerHigh: Color(0xff252b2d),
      surfaceContainerHighest: Color(0xff303638),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme().toColorScheme());
  }

  static MaterialScheme darkHighContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.dark,
      primary: Color(0xfff6fcff),
      surfaceTint: Color(0xff88d1eb),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff8cd5f0),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xfff6fcff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffb7ced9),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfffdf9ff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffc7c7ef),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xfffff9f9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffbab1),
      onErrorContainer: Color(0xff000000),
      background: Color(0xff0f1416),
      onBackground: Color(0xffdee3e6),
      surface: Color(0xff0f1416),
      onSurface: Color(0xffffffff),
      surfaceVariant: Color(0xff40484c),
      onSurfaceVariant: Color(0xfff6fcff),
      outline: Color(0xffc4ccd0),
      outlineVariant: Color(0xffc4ccd0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffdee3e6),
      inverseOnSurface: Color(0xff000000),
      inversePrimary: Color(0xff002e3b),
      primaryFixed: Color(0xffc3eeff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff8cd5f0),
      onPrimaryFixedVariant: Color(0xff001921),
      secondaryFixed: Color(0xffd3ebf5),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb7ced9),
      onSecondaryFixedVariant: Color(0xff021920),
      tertiaryFixed: Color(0xffe6e4ff),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffc7c7ef),
      onTertiaryFixedVariant: Color(0xff111331),
      surfaceDim: Color(0xff0f1416),
      surfaceBright: Color(0xff353a3c),
      surfaceContainerLowest: Color(0xff0a0f11),
      surfaceContainerLow: Color(0xff171c1f),
      surfaceContainer: Color(0xff1b2023),
      surfaceContainerHigh: Color(0xff252b2d),
      surfaceContainerHighest: Color(0xff303638),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme().toColorScheme());
  }


  ThemeData theme(ColorScheme colorScheme) => ThemeData(
     useMaterial3: true,
     brightness: colorScheme.brightness,
     colorScheme: colorScheme,
     textTheme: textTheme.apply(
       bodyColor: colorScheme.onSurface,
       displayColor: colorScheme.onSurface,
     ),
     scaffoldBackgroundColor: colorScheme.background,
     canvasColor: colorScheme.surface,
  );


  List<ExtendedColor> get extendedColors => [
  ];
}

class MaterialScheme {
  const MaterialScheme({
    required this.brightness,
    required this.primary, 
    required this.surfaceTint, 
    required this.onPrimary, 
    required this.primaryContainer, 
    required this.onPrimaryContainer, 
    required this.secondary, 
    required this.onSecondary, 
    required this.secondaryContainer, 
    required this.onSecondaryContainer, 
    required this.tertiary, 
    required this.onTertiary, 
    required this.tertiaryContainer, 
    required this.onTertiaryContainer, 
    required this.error, 
    required this.onError, 
    required this.errorContainer, 
    required this.onErrorContainer, 
    required this.background, 
    required this.onBackground, 
    required this.surface, 
    required this.onSurface, 
    required this.surfaceVariant, 
    required this.onSurfaceVariant, 
    required this.outline, 
    required this.outlineVariant, 
    required this.shadow, 
    required this.scrim, 
    required this.inverseSurface, 
    required this.inverseOnSurface, 
    required this.inversePrimary, 
    required this.primaryFixed, 
    required this.onPrimaryFixed, 
    required this.primaryFixedDim, 
    required this.onPrimaryFixedVariant, 
    required this.secondaryFixed, 
    required this.onSecondaryFixed, 
    required this.secondaryFixedDim, 
    required this.onSecondaryFixedVariant, 
    required this.tertiaryFixed, 
    required this.onTertiaryFixed, 
    required this.tertiaryFixedDim, 
    required this.onTertiaryFixedVariant, 
    required this.surfaceDim, 
    required this.surfaceBright, 
    required this.surfaceContainerLowest, 
    required this.surfaceContainerLow, 
    required this.surfaceContainer, 
    required this.surfaceContainerHigh, 
    required this.surfaceContainerHighest, 
  });

  final Brightness brightness;
  final Color primary;
  final Color surfaceTint;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color shadow;
  final Color scrim;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color inversePrimary;
  final Color primaryFixed;
  final Color onPrimaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixedVariant;
  final Color secondaryFixed;
  final Color onSecondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixedVariant;
  final Color tertiaryFixed;
  final Color onTertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixedVariant;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
}

extension MaterialSchemeUtils on MaterialScheme {
  ColorScheme toColorScheme() {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      background: background,
      onBackground: onBackground,
      surface: surface,
      onSurface: onSurface,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: shadow,
      scrim: scrim,
      inverseSurface: inverseSurface,
      onInverseSurface: inverseOnSurface,
      inversePrimary: inversePrimary,
    );
  }
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
