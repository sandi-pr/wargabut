package id.wargabut.wear.presentation.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Tv
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*
import id.wargabut.wear.data.EventRepository
import id.wargabut.wear.data.WargabutCloudService
import id.wargabut.wear.presentation.theme.*
import id.wargabut.wear.presentation.util.rotaryScroll

@Composable
fun AnimeScreen(
    onDismiss: () -> Unit
) {
    var animeList by remember { mutableStateOf(EventRepository.getTodayAnime()) }
    var isLiveLoaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val cloudAnime = WargabutCloudService.fetchScheduledAnime()
        if (cloudAnime.isNotEmpty()) {
            animeList = cloudAnime
            isLiveLoaded = true
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
            contentPadding = PaddingValues(top = 28.dp, start = 10.dp, end = 10.dp, bottom = 32.dp)
        ) {
            item {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = if (isLiveLoaded) "Jadwal Anime • Live 🌐" else "Jadwal Anime",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF64B5F6),
                        modifier = Modifier.padding(bottom = 2.dp)
                    )
                    Text(
                        text = "Musim Ini / Mendatang (AniNews)",
                        fontSize = 9.sp,
                        color = TextSecondary,
                        modifier = Modifier.padding(bottom = 6.dp)
                    )
                }
            }

            items(animeList.size) { index ->
                val anime = animeList[index]
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 3.dp),
                    shape = RoundedCornerShape(14.dp),
                    backgroundPainter = CardDefaults.cardBackgroundPainter(
                        startBackgroundColor = DarkCard,
                        endBackgroundColor = DarkCard
                    ),
                    onClick = {}
                ) {
                    Column(modifier = Modifier.padding(6.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "📅 ${anime.releaseInfo}",
                                fontSize = 9.sp,
                                color = GoldAccent,
                                fontWeight = FontWeight.Bold
                            )
                            if (anime.airTime.isNotBlank()) {
                                Text(
                                    text = "🕒 ${anime.airTime}",
                                    fontSize = 8.5.sp,
                                    color = Color(0xFF64B5F6),
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }

                        Text(
                            text = anime.title,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextWhite,
                            modifier = Modifier.padding(top = 2.dp)
                        )

                        Text(
                            text = anime.subtitle,
                            fontSize = 9.sp,
                            color = TealAccent,
                            maxLines = 1,
                            modifier = Modifier.padding(top = 1.dp)
                        )
                    }
                }
            }

            item {
                CompactChip(
                    modifier = Modifier.padding(top = 8.dp),
                    label = { Text("Kembali", fontSize = 10.sp) },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
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
