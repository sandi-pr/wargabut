package id.wargabut.wear.data

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.util.regex.Pattern

object EventDateParser {
    private val MONTH_MAP = mapOf(
        "jan" to 1, "januari" to 1, "january" to 1,
        "feb" to 2, "februari" to 2, "february" to 2,
        "mar" to 3, "maret" to 3, "march" to 3,
        "apr" to 4, "april" to 4,
        "mei" to 5, "may" to 5,
        "jun" to 6, "juni" to 6, "june" to 6,
        "jul" to 7, "juli" to 7, "july" to 7,
        "agu" to 8, "agustus" to 8, "aug" to 8, "august" to 8,
        "sep" to 9, "september" to 9,
        "okt" to 10, "oktober" to 10, "oct" to 10, "october" to 10,
        "nov" to 11, "november" to 11,
        "des" to 12, "desember" to 12, "dec" to 12, "december" to 12
    )

    fun parseEndDate(rawDate: String): LocalDate? {
        val clean = rawDate.trim().replace("–", "-").replace("—", "-")
        if (clean.isBlank()) return null

        val yearMatcher = Pattern.compile("\\b(20\\d\\d)\\b").matcher(clean)
        val year = if (yearMatcher.find()) yearMatcher.group(1)?.toIntOrNull() ?: 2026 else 2026

        // Jika rentang (cth: "24-25 Mei 2025" atau "31 Okt - 1 Nov 2026"), ambil bagian setelah strip
        val endPart = if (clean.contains("-")) {
            clean.substringAfterLast("-").trim()
        } else {
            clean
        }

        // Cari bulan di endPart
        var month = -1
        val words = endPart.lowercase(Locale.ROOT).split(Regex("[^a-zA-Z0-9]+"))
        for (w in words) {
            val m = MONTH_MAP[w]
            if (m != null) {
                month = m
                break
            }
        }

        // Jika bulan tidak ada di endPart (misal rentang "24-25 Mei" ada di bagian belakang atau depan)
        if (month == -1) {
            for (w in clean.lowercase(Locale.ROOT).split(Regex("[^a-zA-Z0-9]+"))) {
                val m = MONTH_MAP[w]
                if (m != null) {
                    month = m
                    break
                }
            }
        }
        if (month == -1) return null

        // Cari tanggal hari (angka 1-31)
        var day = -1
        for (w in words) {
            val num = w.toIntOrNull()
            if (num != null && num in 1..31 && num != year) {
                day = num
                break
            }
        }
        if (day == -1) day = 1

        return try {
            LocalDate.of(year, month, day)
        } catch (_: Exception) {
            null
        }
    }

    fun parseStartDate(rawDate: String): LocalDate? {
        val clean = rawDate.trim().replace("–", "-").replace("—", "-")
        if (clean.isBlank()) return null

        val yearMatcher = Pattern.compile("\\b(20\\d\\d)\\b").matcher(clean)
        val year = if (yearMatcher.find()) yearMatcher.group(1)?.toIntOrNull() ?: 2026 else 2026

        val startPart = if (clean.contains("-")) {
            clean.substringBefore("-").trim()
        } else {
            clean
        }

        var month = -1
        for (w in clean.lowercase(Locale.ROOT).split(Regex("[^a-zA-Z0-9]+"))) {
            val m = MONTH_MAP[w]
            if (m != null) {
                month = m
                break
            }
        }
        if (month == -1) return null

        var day = -1
        for (w in startPart.split(Regex("[^0-9]+"))) {
            val num = w.toIntOrNull()
            if (num != null && num in 1..31 && num != year) {
                day = num
                break
            }
        }
        if (day == -1) day = 1

        return try {
            LocalDate.of(year, month, day)
        } catch (_: Exception) {
            null
        }
    }

    fun isEventPast(rawDate: String, today: LocalDate = LocalDate.now()): Boolean {
        val end = parseEndDate(rawDate) ?: return false
        return end.isBefore(today)
    }

    fun getCountdownDays(rawDate: String, today: LocalDate = LocalDate.now()): Int {
        val start = parseStartDate(rawDate) ?: return 0
        val diff = ChronoUnit.DAYS.between(today, start).toInt()
        return if (diff < 0) 0 else diff
    }
}
