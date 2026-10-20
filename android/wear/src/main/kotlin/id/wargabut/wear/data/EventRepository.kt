package id.wargabut.wear.data

data class WargabutEvent(
    val id: String,
    val title: String,
    val dateStr: String,
    val countdownDays: Int,
    val venue: String,
    val transitHint: String,
    val category: String,
    val distanceKm: Double? = null,
    val isOngoing: Boolean = false
)

data class TransitGuide(
    val venueName: String,
    val targetStation: String,
    val lineType: String,
    val steps: List<String>
)

data class AnimeItem(
    val title: String,
    val releaseInfo: String,
    val subtitle: String,
    val airTime: String = ""
)

object EventRepository {
    fun getUpcomingEvents(): List<WargabutEvent> {
        return listOf(
            WargabutEvent(
                id = "ihcx2026",
                title = "Indonesia Hobbies Collector Expo 2026",
                dateStr = "16-18 Okt 2026",
                countdownDays = 0,
                venue = "QBIG BSD CITY - Function Hall 05",
                transitHint = "KRL Rawa Buntu / BSD Link",
                category = "Tangerang",
                distanceKm = 0.7,
                isOngoing = true
            ),
            WargabutEvent(
                id = "cf23",
                title = "Comic Frontier 23",
                dateStr = "31 Okt - 1 Nov 2026",
                countdownDays = 15,
                venue = "ICE BSD City",
                transitHint = "KRL Stasiun Rawa Buntu -> Shuttle ICE",
                category = "Kabupaten Tangerang",
                distanceKm = 1.2
            ),
            WargabutEvent(
                id = "igx3",
                title = "IGX Stage 3",
                dateStr = "24-25 Okt 2026",
                countdownDays = 8,
                venue = "ICE BSD Hall 09-10",
                transitHint = "KRL Stasiun Rawa Buntu -> Shuttle ICE",
                category = "Kabupaten Tangerang",
                distanceKm = 1.2
            ),
            WargabutEvent(
                id = "toyfinity3",
                title = "Jakarta Toyfinity Week Vol. 3 - 2026",
                dateStr = "14-18 Okt 2026",
                countdownDays = 0,
                venue = "Lippo Mall Puri, Jakarta Barat",
                transitHint = "KRL Rawa Buaya / TJ Koridor 3",
                category = "Jakarta Barat",
                distanceKm = 15.7,
                isOngoing = true
            ),
            WargabutEvent(
                id = "jjm2026",
                title = "Jak Japan Matsuri 2026",
                dateStr = "31 Okt - 1 Nov 2026",
                countdownDays = 15,
                venue = "Plaza Parkir Timur, GBK Senayan",
                transitHint = "MRT Istora Mandiri / KRL Palmerah",
                category = "Jakarta Pusat",
                distanceKm = 20.1
            ),
            WargabutEvent(
                id = "metalnightmare",
                title = "Metal Nightmare",
                dateStr = "17-18 Okt 2026",
                countdownDays = 1,
                venue = "ITC Depok",
                transitHint = "KRL Stasiun Depok Baru",
                category = "Depok",
                distanceKm = 23.2
            )
        )
    }

    fun getTransitGuides(): List<TransitGuide> {
        return listOf(
            TransitGuide(
                venueName = "ICE BSD City",
                targetStation = "Stasiun Rawa Buntu (KRL)",
                lineType = "KRL Rangkasbitung Line",
                steps = listOf(
                    "Naik KRL arah Serpong / Rangkasbitung",
                    "Turun di Stasiun Rawa Buntu",
                    "Lanjut Shuttle Bus ICE BSD / Ojol (±10 menit)"
                )
            ),
            TransitGuide(
                venueName = "JCC / GBK Senayan",
                targetStation = "Stasiun Istora Mandiri (MRT)",
                lineType = "MRT Jakarta Line",
                steps = listOf(
                    "Naik MRT Jakarta arah Bundaran HI / Lebak Bulus",
                    "Turun di Stasiun Istora Mandiri (Pintu B)",
                    "Jalan kaki 3 menit ke Pintu 7 GBK"
                )
            ),
            TransitGuide(
                venueName = "JIExpo Kemayoran",
                targetStation = "Stasiun Rajawali (KRL)",
                lineType = "KRL Cikarang / Loop Line",
                steps = listOf(
                    "Naik KRL turun di Stasiun Rajawali / Kemayoran",
                    "Lanjut Shuttle JIExpo / Mikrotrans JAK-33"
                )
            ),
            TransitGuide(
                venueName = "SMESCO Convention Hall",
                targetStation = "Stasiun Pancoran (LRT)",
                lineType = "LRT Jabodebek / TJ Koridor 9",
                steps = listOf(
                    "Naik LRT Jabodebek turun di Pancoran",
                    "Atau TransJakarta Koridor 9 halte Pancoran Tugu"
                )
            )
        )
    }

    fun getTodayAnime(): List<AnimeItem> {
        return listOf(
            AnimeItem(
                title = "Ao Ashi Season 2",
                releaseInfo = "Fall 2026",
                subtitle = "Studio: TMS Entertainment",
                airTime = "22:00 WIB"
            ),
            AnimeItem(
                title = "Black Clover 2nd Season",
                releaseInfo = "Fall 2026",
                subtitle = "Studio: Studio Pierrot",
                airTime = "18:30 WIB"
            ),
            AnimeItem(
                title = "Ao no Hako Season 2",
                releaseInfo = "Fall 2026",
                subtitle = "Studio: Electric Circus",
                airTime = "23:00 WIB"
            ),
            AnimeItem(
                title = "BanG Dream! Ave Mujica",
                releaseInfo = "Fall 2026",
                subtitle = "Studio: Nichicaline",
                airTime = "21:30 WIB"
            )
        )
    }
}
