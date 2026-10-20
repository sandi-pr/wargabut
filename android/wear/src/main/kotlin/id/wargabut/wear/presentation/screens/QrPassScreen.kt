package id.wargabut.wear.presentation.screens

import android.app.Activity
import android.graphics.Bitmap
import android.view.WindowManager
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BrightnessHigh
import androidx.compose.material.icons.filled.BrightnessMedium
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*
import id.wargabut.wear.data.QrGenerator
import id.wargabut.wear.data.UserManager
import id.wargabut.wear.presentation.theme.*
import id.wargabut.wear.presentation.util.rotaryScroll

@Composable
fun QrPassScreen(
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val userManager = remember { UserManager.getInstance(context) }
    val user by userManager.profileFlow.collectAsState()

    var isMaxBrightness by remember { mutableStateOf(false) }

    // Efek atur kecerahan layar untuk scan barcode cepat
    DisposableEffect(isMaxBrightness) {
        val window = activity?.window
        if (isMaxBrightness) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val params = window?.attributes
            params?.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
            window?.attributes = params
        } else {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val params = window?.attributes
            params?.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window?.attributes = params
        }

        onDispose {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val params = window?.attributes
            params?.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            window?.attributes = params
        }
    }

    // Generate QR bitmap locally (offline)
    val qrBitmap = remember(user.username) {
        try {
            QrGenerator.generate("https://wargabut.id/@${user.username}", 360)
        } catch (e: Exception) {
            null
        }
    }

    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }

    Scaffold(
        timeText = { TimeText() },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) }
    ) {
        ScalingLazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(DarkBackground)
                .rotaryScroll(listState, focusRequester),
            state = listState,
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = PaddingValues(top = 24.dp, start = 14.dp, end = 14.dp, bottom = 28.dp)
        ) {
            // Header Info
            item {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = user.displayName,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextWhite
                    )
                    Text(
                        text = "@${user.username}",
                        fontSize = 12.sp,
                        color = TealAccent,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = user.role,
                        fontSize = 10.sp,
                        color = TextSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(bottom = 6.dp)
                    )
                }
            }

            // QR Code Box (Putih dengan sudut melengkung)
            item {
                Box(
                    modifier = Modifier
                        .size(150.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color.White)
                        .padding(8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    if (qrBitmap != null) {
                        Image(
                            bitmap = qrBitmap.asImageBitmap(),
                            contentDescription = "QR Code Biodata Wargabut",
                            modifier = Modifier.fillMaxSize()
                        )
                    } else {
                        Text(
                            text = "Gagal memuat QR",
                            color = Color.Black,
                            fontSize = 10.sp
                        )
                    }
                }
            }

            // Panduan scan
            item {
                Text(
                    text = "Arahkan kamera HP ke jam tangan untuk melihat biodata",
                    fontSize = 9.sp,
                    color = TextSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(vertical = 6.dp)
                )
            }

            // Tombol Toggle Max Brightness
            item {
                CompactChip(
                    modifier = Modifier.fillMaxWidth(0.9f),
                    label = {
                        Text(
                            text = if (isMaxBrightness) "Layar Terang: ON" else "Kecerahan Maksimal",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    },
                    icon = {
                        Icon(
                            imageVector = if (isMaxBrightness) Icons.Default.BrightnessHigh else Icons.Default.BrightnessMedium,
                            contentDescription = "Brightness Toggle",
                            tint = if (isMaxBrightness) GoldAccent else TextWhite,
                            modifier = Modifier.size(14.dp)
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(
                        backgroundColor = if (isMaxBrightness) Color(0xFF332A00) else DarkCard
                    ),
                    onClick = {
                        isMaxBrightness = !isMaxBrightness
                    }
                )
            }

            // Tombol Kembali
            item {
                CompactChip(
                    modifier = Modifier.padding(top = 4.dp),
                    label = { Text("Kembali", fontSize = 10.sp) },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
                            modifier = Modifier.size(14.dp)
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(backgroundColor = DarkSurface),
                    onClick = onDismiss
                )
            }
        }
    }
}
