package id.wargabut.wear.presentation.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.Image
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*
import id.wargabut.wear.data.UserManager
import id.wargabut.wear.presentation.theme.*
import id.wargabut.wear.presentation.util.rotaryScroll

@Composable
fun HomeScreen(
    onNavigateToQr: () -> Unit,
    onNavigateToEvents: () -> Unit,
    onNavigateToTransit: () -> Unit,
    onNavigateToAnime: () -> Unit,
    onNavigateToSync: () -> Unit
) {
    val context = LocalContext.current
    val userManager = remember { UserManager.getInstance(context) }
    val user by userManager.profileFlow.collectAsState()

    val listState = rememberScalingLazyListState()
    val focusRequester = remember { FocusRequester() }

    Scaffold(
        timeText = { TimeText() },
        vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) }
    ) {
        ScalingLazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(DarkBackground)
                .rotaryScroll(listState, focusRequester),
            state = listState,
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = PaddingValues(top = 26.dp, start = 12.dp, end = 12.dp, bottom = 32.dp)
        ) {
            // Header / App Title
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(bottom = 6.dp)
                ) {
                    Image(
                        painter = painterResource(id = id.wargabut.wear.R.drawable.wargabut_logo),
                        contentDescription = "Logo Wargabut",
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "WARGABUT.ID",
                        color = RedPrimary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )
                    Text(
                        text = "Halo, ${user.displayName}",
                        color = TextWhite,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1
                    )
                }
            }

            // Primary Chip: Wargabut QR Pass
            item {
                Chip(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    icon = {
                        Icon(
                            imageVector = Icons.Default.QrCode2,
                            contentDescription = "QR Pass",
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    },
                    label = {
                        Text(
                            text = "Kartu ID & QR Pass",
                            fontWeight = FontWeight.Bold,
                            color = TextWhite
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "@${user.username} • Scan Offline",
                            color = Color(0xFFFFCDD2),
                            fontSize = 10.sp
                        )
                    },
                    colors = ChipDefaults.primaryChipColors(
                        backgroundColor = RedPrimary,
                        contentColor = TextWhite
                    ),
                    onClick = onNavigateToQr
                )
            }

            // Chip: Event Terdekat
            item {
                Chip(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Festival,
                            contentDescription = "Event",
                            tint = TealAccent,
                            modifier = Modifier.size(22.dp)
                        )
                    },
                    label = {
                        Text(
                            text = "Event Terdekat",
                            fontWeight = FontWeight.SemiBold
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "CF19, Impactnation, ICC",
                            color = TextSecondary,
                            fontSize = 10.sp
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(
                        backgroundColor = DarkCard
                    ),
                    onClick = onNavigateToEvents
                )
            }

            // Chip: Panduan Transit
            item {
                Chip(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    icon = {
                        Icon(
                            imageVector = Icons.Default.DirectionsTransit,
                            contentDescription = "Transit",
                            tint = GoldAccent,
                            modifier = Modifier.size(22.dp)
                        )
                    },
                    label = {
                        Text(
                            text = "Panduan Transit",
                            fontWeight = FontWeight.SemiBold
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "KRL & MRT ke Venue Event",
                            color = TextSecondary,
                            fontSize = 10.sp
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(
                        backgroundColor = DarkCard
                    ),
                    onClick = onNavigateToTransit
                )
            }

            // Chip: Jadwal Anime Hari Ini
            item {
                Chip(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Tv,
                            contentDescription = "Anime",
                            tint = Color(0xFF64B5F6),
                            modifier = Modifier.size(22.dp)
                        )
                    },
                    label = {
                        Text(
                            text = "Jadwal Anime",
                            fontWeight = FontWeight.SemiBold
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "Musim Ini / Mendatang",
                            color = TextSecondary,
                            fontSize = 10.sp
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(
                        backgroundColor = DarkCard
                    ),
                    onClick = onNavigateToAnime
                )
            }

            // Chip: Akun Saya & Pengaturan
            item {
                CompactChip(
                    modifier = Modifier.padding(top = 6.dp),
                    label = {
                        Text(
                            text = "Akun Saya (@${user.username})",
                            fontSize = 10.sp
                        )
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = "Profile",
                            modifier = Modifier.size(14.dp)
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(
                        backgroundColor = DarkSurface
                    ),
                    onClick = onNavigateToSync
                )
            }
        }
    }
}
