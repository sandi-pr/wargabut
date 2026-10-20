package id.wargabut.wear.presentation

import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.InputDevice
import android.view.MotionEvent
import android.view.ViewConfiguration
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.InputDeviceCompat
import androidx.core.view.MotionEventCompat
import androidx.core.view.ViewConfigurationCompat
import androidx.compose.runtime.remember
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import id.wargabut.wear.data.UserManager
import id.wargabut.wear.presentation.screens.*
import id.wargabut.wear.presentation.theme.WargabutWearTheme
import id.wargabut.wear.presentation.util.RotaryEventDispatcher

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        setContent {
            WargabutWearTheme {
                val context = this
                val userManager = remember { UserManager.getInstance(context) }
                val isLoggedIn = userManager.isLoggedIn()
                val navController = rememberSwipeDismissableNavController()

                val startDestination = if (isLoggedIn) "home" else "pair"

                SwipeDismissableNavHost(
                    navController = navController,
                    startDestination = startDestination
                ) {
                    composable("pair") {
                        PairingScreen(
                            onPairingSuccess = {
                                navController.navigate("home") {
                                    popUpTo("pair") { inclusive = true }
                                }
                            }
                        )
                    }

                    composable("home") {
                        HomeScreen(
                            onNavigateToQr = { navController.navigate("qr") },
                            onNavigateToEvents = { navController.navigate("events") },
                            onNavigateToTransit = { navController.navigate("transit") },
                            onNavigateToAnime = { navController.navigate("anime") },
                            onNavigateToSync = { navController.navigate("sync") }
                        )
                    }

                    composable("qr") {
                        QrPassScreen(
                            onDismiss = { navController.popBackStack() }
                        )
                    }

                    composable("events") {
                        EventsScreen(
                            onDismiss = { navController.popBackStack() }
                        )
                    }

                    composable("transit") {
                        TransitScreen(
                            onDismiss = { navController.popBackStack() }
                        )
                    }

                    composable("anime") {
                        AnimeScreen(
                            onDismiss = { navController.popBackStack() }
                        )
                    }

                    composable("sync") {
                        SyncScreen(
                            onDismiss = { navController.popBackStack() },
                            onLogout = {
                                navController.navigate("pair") {
                                    popUpTo("home") { inclusive = true }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL &&
            (event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER) ||
             event.isFromSource(InputDeviceCompat.SOURCE_ROTARY_ENCODER))
        ) {
            val axis = if (event.getAxisValue(MotionEvent.AXIS_SCROLL) != 0f) {
                event.getAxisValue(MotionEvent.AXIS_SCROLL)
            } else {
                event.getAxisValue(MotionEvent.AXIS_VSCROLL)
            }

            if (axis != 0f) {
                val scrollFactor = ViewConfigurationCompat.getScaledVerticalScrollFactor(
                    ViewConfiguration.get(this), this
                ).let { if (it > 0f) it else 64f }

                // Negasi karena putaran searah jarum jam menghasilkan axis negatif untuk scroll ke bawah
                val delta = -axis * scrollFactor
                RotaryEventDispatcher.dispatchScroll(delta)

                try {
                    window.decorView.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                } catch (_: Exception) {}

                return true
            }
        }
        return super.onGenericMotionEvent(event)
    }
}
