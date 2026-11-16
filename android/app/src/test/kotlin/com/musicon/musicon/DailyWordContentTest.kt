package com.musicon.musicon

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class DailyWordContentTest {
    private val zone = TimeZone.getTimeZone("America/Sao_Paulo")
    private fun time(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tz: TimeZone = zone): Long =
        Calendar.getInstance(tz).apply { clear(); set(year, month - 1, day, hour, minute) }.timeInMillis

    @Test fun schedulesAtEightBeforeAndAfterTheMorning() {
        assertEquals(time(2026, 11, 16, 8), DailyWordContent.nextMorning(time(2026, 11, 16, 7, 59), zone))
        assertEquals(time(2026, 11, 17, 8), DailyWordContent.nextMorning(time(2026, 11, 16, 8), zone))
        assertEquals(time(2027, 1, 1, 8), DailyWordContent.nextMorning(time(2026, 12, 31, 23), zone))
    }

    @Test fun daylightSavingKeepsEightLocalRatherThanAdding24Hours() {
        val newYork = TimeZone.getTimeZone("America/New_York")
        val before = time(2026, 3, 7, 8, tz = newYork)
        val next = DailyWordContent.nextMorning(before, newYork)
        assertEquals(time(2026, 3, 8, 8, tz = newYork), next)
        assertEquals(23 * 3_600_000L, next - before)
    }

    @Test fun sameLocalDayHasOneMessageAndEveryCycleIsUnique() {
        val seen = mutableSetOf<DailyWord>()
        val day = Calendar.getInstance(zone).apply { timeInMillis = time(2026, 11, 16, 0) }
        repeat(DailyWordContent.words.size) {
            val morning = day.timeInMillis
            val word = DailyWordContent.forDay(morning, 42, zone)
            assertEquals(word, DailyWordContent.forDay(morning + 23 * 3_600_000L, 42, zone))
            assertTrue(seen.add(word))
            day.add(Calendar.DAY_OF_MONTH, 1)
        }
        assertEquals(DailyWordContent.words.size, seen.size)
    }

    @Test fun contentHasAllCategoriesAndBiblicalReferences() {
        assertEquals(setOf("Bíblica", "Motivacional", "Reflexão"), DailyWordContent.words.map { it.category }.toSet())
        assertTrue(DailyWordContent.words.all { it.text.isNotBlank() })
        assertTrue(DailyWordContent.words.filter { it.category == "Bíblica" }.all { it.reference.startsWith("Inspirada em ") })
        assertNotEquals(DailyWordContent.words.shuffled(kotlin.random.Random(42)), DailyWordContent.words.shuffled(kotlin.random.Random(43)))
    }
}
