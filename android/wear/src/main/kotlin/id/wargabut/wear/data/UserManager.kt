package id.wargabut.wear.data

import android.content.Context
import android.content.SharedPreferences
import androidx.wear.tiles.TileService
import id.wargabut.wear.tile.WargabutQrTileService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class WearUserProfile(
    val username: String,
    val displayName: String,
    val role: String,
    val bio: String,
    val instagram: String
)

class UserManager(private val context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("wargabut_wear_prefs", Context.MODE_PRIVATE)

    private val _profileFlow = MutableStateFlow(getProfile())
    val profileFlow: StateFlow<WearUserProfile> = _profileFlow.asStateFlow()

    companion object {
        private const val KEY_IS_LOGGED_IN = "is_logged_in"
        private const val KEY_USERNAME = "username"
        private const val KEY_DISPLAY_NAME = "display_name"
        private const val KEY_ROLE = "role"
        private const val KEY_BIO = "bio"
        private const val KEY_INSTAGRAM = "instagram"

        @Volatile
        private var INSTANCE: UserManager? = null

        fun getInstance(context: Context): UserManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: UserManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }

    fun isLoggedIn(): Boolean {
        return prefs.getBoolean(KEY_IS_LOGGED_IN, false)
    }

    fun getProfile(): WearUserProfile {
        if (!isLoggedIn()) {
            return WearUserProfile(
                username = "tamu",
                displayName = "Pengguna Wargabut",
                role = "Belum Terhubung",
                bio = "Hubungkan akun via wargabut.id/wear",
                instagram = ""
            )
        }

        val username = prefs.getString(KEY_USERNAME, "wargabut") ?: "wargabut"
        val displayName = prefs.getString(KEY_DISPLAY_NAME, "Member") ?: "Member"
        val role = prefs.getString(KEY_ROLE, "Wargabut Member") ?: "Wargabut Member"
        val bio = prefs.getString(KEY_BIO, "Member Wargabut.id") ?: "Member Wargabut.id"
        val instagram = prefs.getString(KEY_INSTAGRAM, "") ?: ""

        return WearUserProfile(
            username = username,
            displayName = displayName,
            role = role,
            bio = bio,
            instagram = instagram
        )
    }

    fun savePairedUser(profile: WearUserProfile) {
        prefs.edit()
            .putBoolean(KEY_IS_LOGGED_IN, true)
            .putString(KEY_USERNAME, profile.username.trim().removePrefix("@"))
            .putString(KEY_DISPLAY_NAME, profile.displayName.ifBlank { profile.username })
            .putString(KEY_ROLE, profile.role.ifBlank { "Wargabut Member" })
            .putString(KEY_BIO, profile.bio)
            .putString(KEY_INSTAGRAM, profile.instagram)
            .apply()

        _profileFlow.value = getProfile()

        try {
            TileService.getUpdater(context).requestUpdate(WargabutQrTileService::class.java)
        } catch (_: Exception) {}
    }

    fun saveProfile(
        username: String,
        displayName: String = username,
        role: String = "Wargabut Member",
        bio: String = "",
        instagram: String = ""
    ) {
        savePairedUser(
            WearUserProfile(
                username = username,
                displayName = displayName,
                role = role,
                bio = bio,
                instagram = instagram
            )
        )
    }

    fun logout() {
        prefs.edit().clear().apply()
        _profileFlow.value = getProfile()

        try {
            TileService.getUpdater(context).requestUpdate(WargabutQrTileService::class.java)
        } catch (_: Exception) {}
    }

    fun getProfileUrl(): String {
        val username = getProfile().username
        return "https://wargabut.id/@$username"
    }
}
