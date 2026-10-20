package id.wargabut.wear.presentation.theme

import androidx.compose.runtime.Composable
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme

val WargabutColorPalette = Colors(
    primary = RedPrimary,
    primaryVariant = RedVariant,
    secondary = TealAccent,
    background = DarkBackground,
    surface = DarkSurface,
    onPrimary = TextWhite,
    onSecondary = TextWhite,
    onBackground = TextWhite,
    onSurface = TextWhite
)

@Composable
fun WargabutWearTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colors = WargabutColorPalette,
        typography = WargabutTypography,
        content = content
    )
}
