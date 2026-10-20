package id.wargabut.wear.tile

import android.content.ComponentName
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.DeviceParametersBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.material.ChipColors
import androidx.wear.protolayout.material.CompactChip
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import id.wargabut.wear.data.UserManager
import id.wargabut.wear.presentation.MainActivity

class WargabutQrTileService : TileService() {

    companion object {
        private const val RESOURCES_VERSION = "1"
    }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val user = UserManager.getInstance(this).getProfile()

        val launchAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setPackageName(packageName)
                    .setClassName(MainActivity::class.java.name)
                    .build()
            )
            .build()

        val clickable = ModifiersBuilders.Clickable.Builder()
            .setOnClick(launchAction)
            .build()

        val layout = PrimaryLayout.Builder(requestParams.deviceConfiguration)
            .setPrimaryLabelTextContent(
                Text.Builder(this, "WARGABUT PASS")
                    .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                    .setColor(ColorBuilders.argb(0xFFE53935.toInt()))
                    .build()
            )
            .setContent(
                LayoutElementBuilders.Column.Builder()
                    .setWidth(DimensionBuilders.wrap())
                    .setHeight(DimensionBuilders.wrap())
                    .setModifiers(ModifiersBuilders.Modifiers.Builder().setClickable(clickable).build())
                    .addContent(
                        Text.Builder(this, user.displayName)
                            .setTypography(Typography.TYPOGRAPHY_TITLE3)
                            .setColor(ColorBuilders.argb(0xFFFFFFFF.toInt()))
                            .build()
                    )
                    .addContent(
                        Text.Builder(this, "@${user.username}")
                            .setTypography(Typography.TYPOGRAPHY_BODY2)
                            .setColor(ColorBuilders.argb(0xFF00BFA5.toInt()))
                            .build()
                    )
                    .addContent(
                        LayoutElementBuilders.Spacer.Builder()
                            .setHeight(DimensionBuilders.dp(6f))
                            .build()
                    )
                    .addContent(
                        Text.Builder(this, "👆 Ketuk untuk Buka QR Code")
                            .setTypography(Typography.TYPOGRAPHY_CAPTION2)
                            .setColor(ColorBuilders.argb(0xFFAAAAAA.toInt()))
                            .build()
                    )
                    .build()
            )
            .setPrimaryChipContent(
                CompactChip.Builder(this, "Tampilkan QR", clickable, requestParams.deviceConfiguration)
                    .setChipColors(
                        ChipColors(
                            ColorBuilders.argb(0xFFE53935.toInt()),
                            ColorBuilders.argb(0xFFFFFFFF.toInt())
                        )
                    )
                    .build()
            )
            .build()

        val timeline = androidx.wear.protolayout.TimelineBuilders.Timeline.fromLayoutElement(layout)

        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(timeline)
            .setFreshnessIntervalMillis(60 * 1000)
            .build()

        return Futures.immediateFuture(tile)
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest
    ): ListenableFuture<androidx.wear.protolayout.ResourceBuilders.Resources> {
        return Futures.immediateFuture(
            androidx.wear.protolayout.ResourceBuilders.Resources.Builder()
                .setVersion(RESOURCES_VERSION)
                .build()
        )
    }
}
