package id.wargabut.wear.presentation.screens

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.Person
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*
import id.wargabut.wear.data.UserManager
import id.wargabut.wear.data.WargabutCloudService
import id.wargabut.wear.presentation.theme.*
import id.wargabut.wear.presentation.util.rotaryScroll
import kotlinx.coroutines.launch

@Composable
fun SyncScreen(
    onDismiss: () -> Unit,
    onLogout: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val userManager = remember { UserManager.getInstance(context) }
    var currentProfile by remember { mutableStateOf(userManager.getProfile()) }
    var isSyncingCloud by remember { mutableStateOf(false) }

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
                        text = "Akun Saya",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextWhite
                    )
                    Text(
                        text = "Smartwatch Terverifikasi",
                        fontSize = 9.sp,
                        color = TealAccent,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Kartu Profil Pengguna
            item {
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
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(RedPrimary.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Person,
                                contentDescription = "Avatar",
                                tint = RedPrimary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = currentProfile.displayName,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextWhite,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = "@${currentProfile.username}",
                            fontSize = 10.sp,
                            color = TealAccent,
                            fontWeight = FontWeight.SemiBold
                        )
                        if (currentProfile.role.isNotBlank()) {
                            Text(
                                text = currentProfile.role,
                                fontSize = 9.sp,
                                color = GoldAccent,
                                modifier = Modifier.padding(top = 2.dp)
                            )
                        }
                        if (currentProfile.bio.isNotBlank()) {
                            Text(
                                text = currentProfile.bio,
                                fontSize = 8.5.sp,
                                color = TextSecondary,
                                textAlign = TextAlign.Center,
                                maxLines = 2,
                                modifier = Modifier.padding(top = 2.dp)
                            )
                        }
                    }
                }
            }

            // Tombol Sinkronkan Data Terbaru dari wargabut.id
            item {
                Chip(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    label = {
                        Text(
                            text = if (isSyncingCloud) "Menghubungi Cloud..." else "Sinkron Ulang Data",
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.Bold
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "Perbarui biodata dari web",
                            fontSize = 8.5.sp,
                            color = Color(0xFFFFCDD2)
                        )
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.CloudDownload,
                            contentDescription = "Cloud Sync",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    },
                    colors = ChipDefaults.primaryChipColors(
                        backgroundColor = RedPrimary,
                        contentColor = TextWhite
                    ),
                    onClick = {
                        if (!isSyncingCloud) {
                            coroutineScope.launch {
                                isSyncingCloud = true
                                val cloudProfile = WargabutCloudService.fetchUserProfile(currentProfile.username)
                                isSyncingCloud = false
                                if (cloudProfile != null) {
                                    userManager.saveProfile(
                                        username = cloudProfile.username,
                                        displayName = cloudProfile.displayName,
                                        role = cloudProfile.role,
                                        bio = cloudProfile.bio,
                                        instagram = cloudProfile.instagram
                                    )
                                    currentProfile = userManager.getProfile()
                                    Toast.makeText(context, "Profil berhasil diperbarui!", Toast.LENGTH_SHORT).show()
                                } else {
                                    Toast.makeText(context, "Gagal mengambil data atau offline", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }
                    }
                )
            }

            // Tombol Putuskan Hubungan / Keluar (Logout)
            item {
                Chip(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    label = {
                        Text(
                            text = "Putuskan Hubungan",
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFFFF8A80)
                        )
                    },
                    secondaryLabel = {
                        Text(
                            text = "Keluar dari jam tangan ini",
                            fontSize = 8.5.sp,
                            color = TextSecondary
                        )
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Logout,
                            contentDescription = "Logout",
                            tint = Color(0xFFFF5252),
                            modifier = Modifier.size(16.dp)
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(
                        backgroundColor = DarkSurface
                    ),
                    onClick = {
                        userManager.logout()
                        Toast.makeText(context, "Akun berhasil diputuskan", Toast.LENGTH_SHORT).show()
                        onLogout()
                    }
                )
            }

            item {
                CompactChip(
                    modifier = Modifier.padding(top = 6.dp),
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
