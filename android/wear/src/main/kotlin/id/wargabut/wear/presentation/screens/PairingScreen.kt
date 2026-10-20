package id.wargabut.wear.presentation.screens

import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*
import id.wargabut.wear.R
import id.wargabut.wear.data.UserManager
import id.wargabut.wear.data.WargabutCloudService
import id.wargabut.wear.presentation.theme.*
import id.wargabut.wear.presentation.util.rotaryScroll
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.random.Random

@Composable
fun PairingScreen(
    onPairingSuccess: () -> Unit
) {
    val context = LocalContext.current
    val userManager = remember { UserManager.getInstance(context) }

    fun generateNewCode(): String {
        val num = Random.nextInt(1000, 9999)
        return "WB-$num"
    }

    var pairingCode by remember { mutableStateOf(generateNewCode()) }
    var isChecking by remember { mutableStateOf(true) }

    // Coroutine polling ke cloud Firestore wear_pairings/{code}
    LaunchedEffect(pairingCode) {
        isChecking = true
        while (isActive) {
            delay(2500)
            val pairedProfile = WargabutCloudService.checkPairing(pairingCode)
            if (pairedProfile != null) {
                userManager.savePairedUser(pairedProfile)
                Toast.makeText(
                    context,
                    "Berhasil terhubung ke @${pairedProfile.username}!",
                    Toast.LENGTH_LONG
                ).show()
                onPairingSuccess()
                break
            }
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
            contentPadding = PaddingValues(top = 26.dp, start = 12.dp, end = 12.dp, bottom = 30.dp)
        ) {
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(bottom = 4.dp)
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.wargabut_logo),
                        contentDescription = "Logo",
                        modifier = Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "HUBUNGKAN AKUN",
                        color = RedPrimary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.2.sp
                    )
                    Text(
                        text = "Metode Web Pairing",
                        color = TextSecondary,
                        fontSize = 9.sp
                    )
                }
            }

            // Box Kode Pairing Besar
            item {
                Box(
                    modifier = Modifier
                        .padding(vertical = 6.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(DarkCard)
                        .border(1.5.dp, GoldAccent, RoundedCornerShape(12.dp))
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = pairingCode,
                        color = GoldAccent,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = 2.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }

            // Petunjuk Step by Step
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = "1. Buka wargabut.id/wear di browser HP",
                        fontSize = 9.sp,
                        color = TextWhite,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        text = "2. Masukkan kode di atas",
                        fontSize = 9.sp,
                        color = TealAccent,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
            }

            // Indikator Menunggu
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(vertical = 4.dp)
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(12.dp),
                        strokeWidth = 2.dp,
                        indicatorColor = RedPrimary
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Menunggu konfirmasi web...",
                        fontSize = 8.5.sp,
                        color = TextSecondary
                    )
                }
            }

            // Tombol Ganti Kode
            item {
                CompactChip(
                    modifier = Modifier.padding(top = 4.dp),
                    label = { Text("Kode Baru", fontSize = 9.sp) },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            modifier = Modifier.size(12.dp)
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(backgroundColor = DarkSurface),
                    onClick = {
                        pairingCode = generateNewCode()
                    }
                )
            }
        }
    }
}
