import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static MaterialScheme lightScheme() {
    return const MaterialScheme(
      brightness: Brightness.light,
      primary: Color(4278609791),
      surfaceTint: Color(4278609791),
      onPrimary: Color(4294967295),
      primaryContainer: Color(4290243327),
      onPrimaryContainer: Color(4278198056),
      secondary: Color(4283196010),
      onSecondary: Color(4294967295),
      secondaryContainer: Color(4291815153),
      onSecondaryContainer: Color(4278656550),
      tertiary: Color(4284111998),
      onTertiary: Color(4294967295),
      tertiaryContainer: Color(4292927743),
      onTertiaryContainer: Color(4279703863),
      error: Color(4290386458),
      onError: Color(4294967295),
      errorContainer: Color(4294957782),
      onErrorContainer: Color(4282449922),
      background: Color(4294310653),
      onBackground: Color(4279704607),
      surface: Color(4294310653),
      onSurface: Color(4279704607),
      surfaceVariant: Color(4292601064),
      onSurfaceVariant: Color(4282402892),
      outline: Color(4285560956),
      outlineVariant: Color(4290758860),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4281086260),
      inverseOnSurface: Color(4293784052),
      inversePrimary: Color(4287156715),
      primaryFixed: Color(4290243327),
      onPrimaryFixed: Color(4278198056),
      primaryFixedDim: Color(4287156715),
      onPrimaryFixedVariant: Color(4278210144),
      secondaryFixed: Color(4291815153),
      onSecondaryFixed: Color(4278656550),
      secondaryFixedDim: Color(4289972948),
      onSecondaryFixedVariant: Color(4281616978),
      tertiaryFixed: Color(4292927743),
      onTertiaryFixed: Color(4279703863),
      tertiaryFixedDim: Color(4291019755),
      onTertiaryFixedVariant: Color(4282532965),
      surfaceDim: Color(4292271070),
      surfaceBright: Color(4294310653),
      surfaceContainerLowest: Color(4294967295),
      surfaceContainerLow: Color(4293915895),
      surfaceContainer: Color(4293586929),
      surfaceContainerHigh: Color(4293192172),
      surfaceContainerHighest: Color(4292797414),
    );
  }

  ThemeData light() {
    return theme(lightScheme().toColorScheme());
  }

  static MaterialScheme lightMediumContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.light,
      primary: Color(4278208859),
      surfaceTint: Color(4278609791),
      onPrimary: Color(4294967295),
      primaryContainer: Color(4281237142),
      onPrimaryContainer: Color(4294967295),
      secondary: Color(4281353806),
      onSecondary: Color(4294967295),
      secondaryContainer: Color(4284643457),
      onSecondaryContainer: Color(4294967295),
      tertiary: Color(4282269793),
      onTertiary: Color(4294967295),
      tertiaryContainer: Color(4285559445),
      onTertiaryContainer: Color(4294967295),
      error: Color(4287365129),
      onError: Color(4294967295),
      errorContainer: Color(4292490286),
      onErrorContainer: Color(4294967295),
      background: Color(4294310653),
      onBackground: Color(4279704607),
      surface: Color(4294310653),
      onSurface: Color(4279704607),
      surfaceVariant: Color(4292601064),
      onSurfaceVariant: Color(4282139720),
      outline: Color(4283981924),
      outlineVariant: Color(4285824128),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4281086260),
      inverseOnSurface: Color(4293784052),
      inversePrimary: Color(4287156715),
      primaryFixed: Color(4281237142),
      onPrimaryFixed: Color(4294967295),
      primaryFixedDim: Color(4278215804),
      onPrimaryFixedVariant: Color(4294967295),
      secondaryFixed: Color(4284643457),
      onSecondaryFixed: Color(4294967295),
      secondaryFixedDim: Color(4282998632),
      onSecondaryFixedVariant: Color(4294967295),
      tertiaryFixed: Color(4285559445),
      onTertiaryFixed: Color(4294967295),
      tertiaryFixedDim: Color(4283980155),
      onTertiaryFixedVariant: Color(4294967295),
      surfaceDim: Color(4292271070),
      surfaceBright: Color(4294310653),
      surfaceContainerLowest: Color(4294967295),
      surfaceContainerLow: Color(4293915895),
      surfaceContainer: Color(4293586929),
      surfaceContainerHigh: Color(4293192172),
      surfaceContainerHighest: Color(4292797414),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme().toColorScheme());
  }

  static MaterialScheme lightHighContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.light,
      primary: Color(4278199857),
      surfaceTint: Color(4278609791),
      onPrimary: Color(4294967295),
      primaryContainer: Color(4278208859),
      onPrimaryContainer: Color(4294967295),
      secondary: Color(4279117101),
      onSecondary: Color(4294967295),
      secondaryContainer: Color(4281353806),
      onSecondaryContainer: Color(4294967295),
      tertiary: Color(4280098622),
      onTertiary: Color(4294967295),
      tertiaryContainer: Color(4282269793),
      onTertiaryContainer: Color(4294967295),
      error: Color(4283301890),
      onError: Color(4294967295),
      errorContainer: Color(4287365129),
      onErrorContainer: Color(4294967295),
      background: Color(4294310653),
      onBackground: Color(4279704607),
      surface: Color(4294310653),
      onSurface: Color(4278190080),
      surfaceVariant: Color(4292601064),
      onSurfaceVariant: Color(4280100136),
      outline: Color(4282139720),
      outlineVariant: Color(4282139720),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4281086260),
      inverseOnSurface: Color(4294967295),
      inversePrimary: Color(4291949055),
      primaryFixed: Color(4278208859),
      onPrimaryFixed: Color(4294967295),
      primaryFixedDim: Color(4278202686),
      onPrimaryFixedVariant: Color(4294967295),
      secondaryFixed: Color(4281353806),
      onSecondaryFixed: Color(4294967295),
      secondaryFixedDim: Color(4279906359),
      onSecondaryFixedVariant: Color(4294967295),
      tertiaryFixed: Color(4282269793),
      onTertiaryFixed: Color(4294967295),
      tertiaryFixedDim: Color(4280822345),
      onTertiaryFixedVariant: Color(4294967295),
      surfaceDim: Color(4292271070),
      surfaceBright: Color(4294310653),
      surfaceContainerLowest: Color(4294967295),
      surfaceContainerLow: Color(4293915895),
      surfaceContainer: Color(4293586929),
      surfaceContainerHigh: Color(4293192172),
      surfaceContainerHighest: Color(4292797414),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme().toColorScheme());
  }

  static MaterialScheme darkScheme() {
    return const MaterialScheme(
      brightness: Brightness.dark,
      primary: Color(4287156715),
      surfaceTint: Color(4287156715),
      onPrimary: Color(4278203715),
      primaryContainer: Color(4278210144),
      onPrimaryContainer: Color(4290243327),
      secondary: Color(4289972948),
      onSecondary: Color(4280169275),
      secondaryContainer: Color(4281616978),
      onSecondaryContainer: Color(4291815153),
      tertiary: Color(4291019755),
      onTertiary: Color(4281085517),
      tertiaryContainer: Color(4282532965),
      onTertiaryContainer: Color(4292927743),
      error: Color(4294948011),
      onError: Color(4285071365),
      errorContainer: Color(4287823882),
      onErrorContainer: Color(4294957782),
      background: Color(4279178262),
      onBackground: Color(4292797414),
      surface: Color(4279178262),
      onSurface: Color(4292797414),
      surfaceVariant: Color(4282402892),
      onSurfaceVariant: Color(4290758860),
      outline: Color(4287271574),
      outlineVariant: Color(4282402892),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4292797414),
      inverseOnSurface: Color(4281086260),
      inversePrimary: Color(4278609791),
      primaryFixed: Color(4290243327),
      onPrimaryFixed: Color(4278198056),
      primaryFixedDim: Color(4287156715),
      onPrimaryFixedVariant: Color(4278210144),
      secondaryFixed: Color(4291815153),
      onSecondaryFixed: Color(4278656550),
      secondaryFixedDim: Color(4289972948),
      onSecondaryFixedVariant: Color(4281616978),
      tertiaryFixed: Color(4292927743),
      onTertiaryFixed: Color(4279703863),
      tertiaryFixedDim: Color(4291019755),
      onTertiaryFixedVariant: Color(4282532965),
      surfaceDim: Color(4279178262),
      surfaceBright: Color(4281678396),
      surfaceContainerLowest: Color(4278849297),
      surfaceContainerLow: Color(4279704607),
      surfaceContainer: Color(4279967779),
      surfaceContainerHigh: Color(4280625965),
      surfaceContainerHighest: Color(4281349688),
    );
  }

  ThemeData dark() {
    return theme(darkScheme().toColorScheme());
  }

  static MaterialScheme darkMediumContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.dark,
      primary: Color(4287419888),
      surfaceTint: Color(4287156715),
      onPrimary: Color(4278196513),
      primaryContainer: Color(4283472563),
      onPrimaryContainer: Color(4278190080),
      secondary: Color(4290236121),
      onSecondary: Color(4278327584),
      secondaryContainer: Color(4286485662),
      onSecondaryContainer: Color(4278190080),
      tertiary: Color(4291282927),
      onTertiary: Color(4279309105),
      tertiaryContainer: Color(4287467187),
      onTertiaryContainer: Color(4278190080),
      error: Color(4294949553),
      onError: Color(4281794561),
      errorContainer: Color(4294923337),
      onErrorContainer: Color(4278190080),
      background: Color(4279178262),
      onBackground: Color(4292797414),
      surface: Color(4279178262),
      onSurface: Color(4294441982),
      surfaceVariant: Color(4282402892),
      onSurfaceVariant: Color(4291087568),
      outline: Color(4288455848),
      outlineVariant: Color(4286350472),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4292797414),
      inverseOnSurface: Color(4280625965),
      inversePrimary: Color(4278210402),
      primaryFixed: Color(4290243327),
      onPrimaryFixed: Color(4278195226),
      primaryFixedDim: Color(4287156715),
      onPrimaryFixedVariant: Color(4278205515),
      secondaryFixed: Color(4291815153),
      onSecondaryFixed: Color(4278195226),
      secondaryFixedDim: Color(4289972948),
      onSecondaryFixedVariant: Color(4280564033),
      tertiaryFixed: Color(4292927743),
      onTertiaryFixed: Color(4278980140),
      tertiaryFixedDim: Color(4291019755),
      onTertiaryFixedVariant: Color(4281480019),
      surfaceDim: Color(4279178262),
      surfaceBright: Color(4281678396),
      surfaceContainerLowest: Color(4278849297),
      surfaceContainerLow: Color(4279704607),
      surfaceContainer: Color(4279967779),
      surfaceContainerHigh: Color(4280625965),
      surfaceContainerHighest: Color(4281349688),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme().toColorScheme());
  }

  static MaterialScheme darkHighContrastScheme() {
    return const MaterialScheme(
      brightness: Brightness.dark,
      primary: Color(4294376703),
      surfaceTint: Color(4287156715),
      onPrimary: Color(4278190080),
      primaryContainer: Color(4287419888),
      onPrimaryContainer: Color(4278190080),
      secondary: Color(4294376703),
      onSecondary: Color(4278190080),
      secondaryContainer: Color(4290236121),
      onSecondaryContainer: Color(4278190080),
      tertiary: Color(4294834687),
      onTertiary: Color(4278190080),
      tertiaryContainer: Color(4291282927),
      onTertiaryContainer: Color(4278190080),
      error: Color(4294965753),
      onError: Color(4278190080),
      errorContainer: Color(4294949553),
      onErrorContainer: Color(4278190080),
      background: Color(4279178262),
      onBackground: Color(4292797414),
      surface: Color(4279178262),
      onSurface: Color(4294967295),
      surfaceVariant: Color(4282402892),
      onSurfaceVariant: Color(4294376703),
      outline: Color(4291087568),
      outlineVariant: Color(4291087568),
      shadow: Color(4278190080),
      scrim: Color(4278190080),
      inverseSurface: Color(4292797414),
      inverseOnSurface: Color(4278190080),
      inversePrimary: Color(4278201915),
      primaryFixed: Color(4291030783),
      onPrimaryFixed: Color(4278190080),
      primaryFixedDim: Color(4287419888),
      onPrimaryFixedVariant: Color(4278196513),
      secondaryFixed: Color(4292078581),
      onSecondaryFixed: Color(4278190080),
      secondaryFixedDim: Color(4290236121),
      onSecondaryFixedVariant: Color(4278327584),
      tertiaryFixed: Color(4293321983),
      onTertiaryFixed: Color(4278190080),
      tertiaryFixedDim: Color(4291282927),
      onTertiaryFixedVariant: Color(4279309105),
      surfaceDim: Color(4279178262),
      surfaceBright: Color(4281678396),
      surfaceContainerLowest: Color(4278849297),
      surfaceContainerLow: Color(4279704607),
      surfaceContainer: Color(4279967779),
      surfaceContainerHigh: Color(4280625965),
      surfaceContainerHighest: Color(4281349688),
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
