package id.wargabut.wear.data

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

object WargabutCloudService {
    private const val TAG = "WargabutCloud"
    private const val BASE_URL =
        "https://firestore.googleapis.com/v1/projects/wargabut-11/databases/(default)/documents"

    private fun httpGet(urlStr: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlStr)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.setRequestProperty("Accept", "application/json")

            if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { reader ->
                    reader.readText()
                }
            } else {
                Log.w(TAG, "HTTP ${conn.responseCode} from $urlStr")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Network error fetching $urlStr: ${e.message}")
            null
        } finally {
            conn?.disconnect()
        }
    }

    suspend fun fetchUserProfile(rawUsername: String): WearUserProfile? = withContext(Dispatchers.IO) {
        val username = rawUsername.trim().lowercase().removePrefix("@")
        if (username.isEmpty()) return@withContext null

        try {
            // 1. Ambil UID dari usernames/{username}
            val usernameJsonStr = httpGet("$BASE_URL/usernames/$username") ?: return@withContext null
            val usernameObj = JSONObject(usernameJsonStr)
            val fields = usernameObj.optJSONObject("fields") ?: return@withContext null
            val uid = fields.optJSONObject("uid")?.optString("stringValue") ?: return@withContext null

            // 2. Ambil profil lengkap dari users/{uid}
            val userJsonStr = httpGet("$BASE_URL/users/$uid") ?: return@withContext null
            val userObj = JSONObject(userJsonStr)
            val uFields = userObj.optJSONObject("fields") ?: return@withContext null

            val dName = uFields.optJSONObject("display_name")?.optString("stringValue")?.ifBlank { username } ?: username
            val bio = uFields.optJSONObject("bio")?.optString("stringValue") ?: ""
            val instagram = uFields.optJSONObject("instagram")?.optString("stringValue") ?: ""
            val city = uFields.optJSONObject("city")?.optString("stringValue") ?: ""

            val role = if (city.isNotBlank()) "Wargabut ($city)" else "Wargabut Member"

            WearUserProfile(
                username = username,
                displayName = dName,
                role = role,
                bio = bio,
                instagram = instagram
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching user profile for @$username", e)
            null
        }
    }

    fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val p = 0.017453292519943295
        val a = 0.5 - Math.cos((lat2 - lat1) * p) / 2 +
                Math.cos(lat1 * p) * Math.cos(lat2 * p) * (1 - Math.cos((lon2 - lon1) * p)) / 2
        return 12742.0 * Math.asin(Math.sqrt(a))
    }

    suspend fun fetchLiveEvents(
        userLat: Double = -6.29,
        userLng: Double = 106.64,
        filterNearest: Boolean = true
    ): List<WargabutEvent> = withContext(Dispatchers.IO) {
        val result = mutableListOf<WargabutEvent>()
        try {
            var pageToken: String? = null
            var count = 0

            // Loop pagination untuk mengambil seluruh dokumen dari koleksi jfestchart
            do {
                val url = if (pageToken.isNullOrEmpty()) {
                    "$BASE_URL/jfestchart?pageSize=300"
                } else {
                    "$BASE_URL/jfestchart?pageSize=300&pageToken=$pageToken"
                }

                val jsonStr = httpGet(url) ?: break
                val root = JSONObject(jsonStr)
                val docs = root.optJSONArray("documents") ?: break

                for (i in 0 until docs.length()) {
                    val doc = docs.optJSONObject(i) ?: continue
                    val fields = doc.optJSONObject("fields") ?: continue

                    val eventName = fields.optJSONObject("event_name")?.optString("stringValue") ?: continue
                    if (eventName.isBlank()) continue

                    val dateStr = fields.optJSONObject("date")?.optString("stringValue") ?: ""

                    // Filter event yang sudah lampau / lewat
                    if (dateStr.isNotBlank() && EventDateParser.isEventPast(dateStr)) {
                        continue
                    }

                    val countdown = if (dateStr.isNotBlank()) EventDateParser.getCountdownDays(dateStr) else 0
                    val isOngoing = countdown == 0
                    val location = fields.optJSONObject("location")?.optString("stringValue") ?: ""
                    val area = fields.optJSONObject("area")?.optString("stringValue") ?: "Event"

                    // Ekstrak lat/lng jika ada
                    val latObj = fields.optJSONObject("lat")
                    val lngObj = fields.optJSONObject("lng")
                    val lat = latObj?.optDouble("doubleValue", Double.NaN)
                        ?: (latObj?.optLong("integerValue")?.toDouble() ?: Double.NaN)
                    val lng = lngObj?.optDouble("doubleValue", Double.NaN)
                        ?: (lngObj?.optLong("integerValue")?.toDouble() ?: Double.NaN)

                    var distanceKm: Double? = null
                    if (!lat.isNaN() && !lng.isNaN()) {
                        distanceKm = calculateDistanceKm(userLat, userLng, lat, lng)
                    } else {
                        // Perkiraan jarak jika tidak ada koordinat
                        val lower = (location + " " + area).lowercase(java.util.Locale.ROOT)
                        distanceKm = when {
                            lower.contains("qbig") -> 0.7
                            lower.contains("ice bsd") || lower.contains("ice, bsd") -> 1.2
                            lower.contains("bsd") -> 2.5
                            lower.contains("tangerang") -> 6.0
                            lower.contains("puri") || lower.contains("jakarta barat") -> 15.7
                            lower.contains("senayan") || lower.contains("gbk") || lower.contains("jakarta pusat") -> 20.1
                            lower.contains("depok") -> 23.2
                            lower.contains("green pramuka") -> 28.2
                            lower.contains("kemayoran") || lower.contains("jakarta timur") || lower.contains("jakarta utara") -> 28.0
                            else -> 999.0
                        }
                    }

                    val transitHint = when {
                        location.contains("QBIG", ignoreCase = true) -> "KRL Rawa Buntu / BSD Link"
                        location.contains("ICE", ignoreCase = true) -> "KRL Stasiun Rawa Buntu -> Shuttle ICE"
                        location.contains("Lippo Mall Puri", ignoreCase = true) -> "KRL Rawa Buaya / TJ Koridor 3"
                        location.contains("GBK", ignoreCase = true) || location.contains("Senayan", ignoreCase = true) -> "MRT Istora Mandiri / KRL Palmerah"
                        location.contains("ITC Depok", ignoreCase = true) -> "KRL Stasiun Depok Baru"
                        location.contains("Green Pramuka", ignoreCase = true) -> "TJ Koridor 10 / Stasiun Kramat"
                        location.contains("Velodrome", ignoreCase = true) -> "LRT Velodrome Rawamangun"
                        location.contains("JIExpo", ignoreCase = true) || location.contains("Kemayoran", ignoreCase = true) -> "KRL Stasiun Rajawali"
                        location.contains("Blok M", ignoreCase = true) -> "MRT Blok M BCA"
                        else -> if (area.isNotBlank()) "Area $area" else "Transportasi Umum"
                    }

                    result.add(
                        WargabutEvent(
                            id = "live_${count++}",
                            title = eventName,
                            dateStr = dateStr.ifBlank { "Segera Hadir" },
                            countdownDays = countdown,
                            venue = location.ifBlank { "Jakarta & Sekitarnya" },
                            transitHint = transitHint,
                            category = area,
                            distanceKm = distanceKm,
                            isOngoing = isOngoing
                        )
                    )
                }

                pageToken = root.optString("nextPageToken").ifBlank { null }
            } while (!pageToken.isNullOrEmpty())

            // Urutkan berdasarkan jarak (terdekat) atau waktu (terdekat)
            if (filterNearest) {
                result.sortWith(compareBy({ it.distanceKm ?: 9999.0 }, { it.countdownDays }))
            } else {
                result.sortWith(compareBy({ it.countdownDays }, { it.distanceKm ?: 9999.0 }))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching live events", e)
        }

        if (result.isEmpty()) {
            return@withContext EventRepository.getUpcomingEvents()
        }
        result
    }

    suspend fun fetchScheduledAnime(): List<AnimeItem> = withContext(Dispatchers.IO) {
        val result = mutableListOf<AnimeItem>()
        try {
            val jsonStr = httpGet("$BASE_URL/anichekku?pageSize=20") ?: return@withContext emptyList()
            val root = JSONObject(jsonStr)
            val docs = root.optJSONArray("documents") ?: return@withContext emptyList()

            for (i in 0 until docs.length()) {
                val doc = docs.optJSONObject(i) ?: continue
                val fields = doc.optJSONObject("fields") ?: continue

                val title = fields.optJSONObject("title")?.optString("stringValue") ?: continue
                if (title.isBlank()) continue

                val premiered = fields.optJSONObject("premiered")?.optString("stringValue") ?: ""
                val date = fields.optJSONObject("date")?.optString("stringValue") ?: ""
                val releaseInfo = when {
                    premiered.isNotBlank() -> premiered
                    date.isNotBlank() -> date
                    else -> "Mendatang"
                }

                val studiosArray = fields.optJSONObject("studios")?.optJSONArray("values")
                val studio = studiosArray?.optJSONObject(0)?.optString("stringValue") ?: ""

                val genresArray = fields.optJSONObject("genres")?.optJSONArray("values")
                val genre = genresArray?.optJSONObject(0)?.optString("stringValue") ?: ""

                val airTime = fields.optJSONObject("air_time")?.optString("stringValue")
                    ?: fields.optJSONObject("jam_tayang")?.optString("stringValue") ?: ""

                val subtitle = when {
                    studio.isNotBlank() && genre.isNotBlank() -> "$studio • $genre"
                    studio.isNotBlank() -> "Studio: $studio"
                    genre.isNotBlank() -> "Genre: $genre"
                    else -> "Anime Wargabut"
                }

                result.add(
                    AnimeItem(
                        title = title,
                        releaseInfo = releaseInfo,
                        subtitle = subtitle,
                        airTime = airTime
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching scheduled anime", e)
        }

        if (result.isEmpty()) {
            return@withContext EventRepository.getTodayAnime()
        }
        result
    }

    /**
     * Memeriksa status pairing dari Firestore (wear_pairings/{code})
     */
    suspend fun checkPairing(code: String): WearUserProfile? = withContext(Dispatchers.IO) {
        val cleanCode = code.trim().uppercase()
        if (cleanCode.isEmpty()) return@withContext null
        try {
            val jsonStr = httpGet("$BASE_URL/wear_pairings/$cleanCode") ?: return@withContext null
            val root = JSONObject(jsonStr)
            val fields = root.optJSONObject("fields") ?: return@withContext null

            val status = fields.optJSONObject("status")?.optString("stringValue") ?: ""
            if (status.equals("approved", ignoreCase = true)) {
                val username = fields.optJSONObject("username")?.optString("stringValue") ?: ""
                val displayName = fields.optJSONObject("displayName")?.optString("stringValue")?.ifBlank { username } ?: username
                val role = fields.optJSONObject("role")?.optString("stringValue") ?: "Wargabut Member"
                val bio = fields.optJSONObject("bio")?.optString("stringValue") ?: ""
                val instagram = fields.optJSONObject("instagram")?.optString("stringValue") ?: ""

                if (username.isNotBlank()) {
                    return@withContext WearUserProfile(
                        username = username,
                        displayName = displayName,
                        role = role,
                        bio = bio,
                        instagram = instagram
                    )
                }
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error checking pairing code $cleanCode", e)
            null
        }
    }
}
