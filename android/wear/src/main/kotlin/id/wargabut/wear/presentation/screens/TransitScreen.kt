package id.wargabut.wear.presentation.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DirectionsTransit
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*
import androidx.compose.ui.focus.FocusRequester
import id.wargabut.wear.data.EventRepository
import id.wargabut.wear.presentation.theme.*
import id.wargabut.wear.presentation.util.rotaryScroll

@Composable
fun TransitScreen(
    onDismiss: () -> Unit
) {
    val transitGuides = remember { EventRepository.getTransitGuides() }
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
                    text = "Panduan Transit",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = GoldAccent,
                    modifier = Modifier.padding(bottom = 6.dp)
                )
            }

            items(transitGuides.size) { index ->
                val guide = transitGuides[index]
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    shape = RoundedCornerShape(14.dp),
                    backgroundPainter = CardDefaults.cardBackgroundPainter(
                        startBackgroundColor = DarkCard,
                        endBackgroundColor = DarkCard
                    ),
                    onClick = {}
                ) {
                    Column(modifier = Modifier.padding(6.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.DirectionsTransit,
                                contentDescription = "Transit",
                                tint = GoldAccent,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = guide.venueName,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = TextWhite
                            )
                        }

                        Text(
                            text = "🎯 ${guide.targetStation}",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = TealAccent,
                            modifier = Modifier.padding(top = 3.dp)
                        )

                        Text(
                            text = "Jalur: ${guide.lineType}",
                            fontSize = 9.sp,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 1.dp)
                        )

                        Spacer(modifier = Modifier.height(4.dp))
                        guide.steps.forEachIndexed { stepIdx, step ->
                            Text(
                                text = "${stepIdx + 1}. $step",
                                fontSize = 9.sp,
                                color = TextWhite,
                                modifier = Modifier.padding(vertical = 1.dp)
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
