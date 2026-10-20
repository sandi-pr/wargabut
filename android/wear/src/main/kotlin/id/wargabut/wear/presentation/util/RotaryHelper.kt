package id.wargabut.wear.presentation.util

import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.wear.compose.material.ScalingLazyListState
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch

object RotaryEventDispatcher {
    private val _rotaryEvents = MutableSharedFlow<Float>(
        extraBufferCapacity = 32,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val rotaryEvents = _rotaryEvents.asSharedFlow()

    fun dispatchScroll(delta: Float) {
        _rotaryEvents.tryEmit(delta)
    }
}

@Composable
fun Modifier.rotaryScroll(
    listState: ScalingLazyListState,
    focusRequester: FocusRequester? = null
): Modifier {
    val coroutineScope = rememberCoroutineScope()

    // Jalur 1: Tangkap event hardware langsung dari Activity (100% responsif di Xiaomi Watch 2 Pro)
    LaunchedEffect(listState) {
        RotaryEventDispatcher.rotaryEvents.collect { delta ->
            listState.scrollBy(delta)
        }
    }

    // Jalur 2: Event Compose Focus
    LaunchedEffect(Unit) {
        try {
            focusRequester?.requestFocus()
        } catch (_: Exception) {}
    }

    var mod = this
    if (focusRequester != null) {
        mod = mod
            .focusRequester(focusRequester)
            .focusable()
            .onRotaryScrollEvent { event ->
                coroutineScope.launch {
                    listState.scrollBy(event.verticalScrollPixels)
                }
                true
            }
    }

    return mod
}
