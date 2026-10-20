package id.wargabut.wear.presentation.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DirectionsTransit
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
fun EventsScreen(
    onDismiss: () -> Unit
) {
    var events by remember { mutableStateOf(EventRepository.getUpcomingEvents()) }
    var isLiveLoaded by remember { mutableStateOf(false) }
    var filterNearest by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        val liveList = WargabutCloudService.fetchLiveEvents(filterNearest = true)
        if (liveList.isNotEmpty()) {
            events = liveList
            isLiveLoaded = true
        }
    }

    val displayedEvents = remember(events, filterNearest) {
        if (filterNearest) {
            events.sortedWith(compareBy({ it.distanceKm ?: 9999.0 }, { it.countdownDays }))
        } else {
            events.sortedWith(compareBy({ it.countdownDays }, { it.distanceKm ?: 9999.0 }))
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
                Text(
                    text = if (isLiveLoaded) "Event Wargabut • Live 🌐" else "Event Wargabut",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = RedPrimary,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }

            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 6.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CompactChip(
                        label = {
                            Text(
                                text = if (filterNearest) "✓ Terdekat" else "Terdekat",
                                fontSize = 9.sp,
                                fontWeight = if (filterNearest) FontWeight.Bold else FontWeight.Normal
                            )
                        },
                        colors = if (filterNearest) {
                            ChipDefaults.primaryChipColors(backgroundColor = RedPrimary)
                        } else {
                            ChipDefaults.secondaryChipColors(backgroundColor = DarkSurface)
                        },
                        onClick = { filterNearest = true }
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    CompactChip(
                        label = {
                            Text(
                                text = if (!filterNearest) "✓ Waktu" else "📅 Waktu",
                                fontSize = 9.sp,
                                fontWeight = if (!filterNearest) FontWeight.Bold else FontWeight.Normal
                            )
                        },
                        colors = if (!filterNearest) {
                            ChipDefaults.primaryChipColors(backgroundColor = RedPrimary)
                        } else {
                            ChipDefaults.secondaryChipColors(backgroundColor = DarkSurface)
                        },
                        onClick = { filterNearest = false }
                    )
                }
            }

            items(displayedEvents.size) { index ->
                val event = displayedEvents[index]
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    shape = RoundedCornerShape(14.dp),
                    backgroundPainter = CardDefaults.cardBackgroundPainter(
                        startBackgroundColor = DarkCard,
                        endBackgroundColor = DarkCard
                    ),
                    onClick = { /* Event detail or expand */ }
                ) {
                    Column(modifier = Modifier.padding(6.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = event.category,
                                fontSize = 9.sp,
                                color = TealAccent,
                                fontWeight = FontWeight.SemiBold
                            )
                            val isToday = event.isOngoing || event.countdownDays == 0
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(if (isToday) RedPrimary else DarkSurface)
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    text = if (isToday) "HARI INI" else "H-${event.countdownDays}",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isToday) Color.White else GoldAccent
                                )
                            }
                        }

                        Text(
                            text = event.title,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextWhite,
                            modifier = Modifier.padding(top = 2.dp)
                        )

                        Text(
                            text = "📅 ${event.dateStr}",
                            fontSize = 10.sp,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 2.dp)
                        )

                        Row(
                            modifier = Modifier.padding(top = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = "Venue",
                                tint = GoldAccent,
                                modifier = Modifier.size(11.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            val distText = if (event.distanceKm != null && event.distanceKm < 900.0) {
                                " (~${String.format(java.util.Locale.US, "%.1f", event.distanceKm)} km)"
                            } else ""
                            Text(
                                text = "${event.venue}$distText",
                                fontSize = 9.sp,
                                color = TextWhite,
                                maxLines = 1
                            )
                        }

                        Row(
                            modifier = Modifier.padding(top = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.DirectionsTransit,
                                contentDescription = "Transit",
                                tint = TealAccent,
                                modifier = Modifier.size(11.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = event.transitHint,
                                fontSize = 9.sp,
                                color = TextSecondary,
                                maxLines = 1
                            )
                        }
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
