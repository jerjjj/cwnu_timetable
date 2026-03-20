package com.example.cwnu_demo

import android.content.Context
import android.graphics.Color
import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

data class WidgetCourseInfo(
    val courseName: String,
    val placeName: String,
    val teacher: String,
    val startPeriod: Int,
    val endPeriod: Int,
    val isCurrent: Boolean,
)

object TimetableWidgetDataSource {
    private val periodTime = mapOf(
        1 to "08:00-08:40",
        2 to "08:50-09:30",
        3 to "09:45-10:25",
        4 to "10:35-11:15",
        5 to "11:25-12:05",
        6 to "14:30-15:10",
        7 to "15:20-16:00",
        8 to "16:10-16:50",
        9 to "17:00-17:40",
        10 to "19:00-19:40",
        11 to "19:50-20:30",
        12 to "20:40-21:20",
    )

    fun buildHeaderText(context: Context): String {
        val today = LocalDate.now()
        val week = computeCurrentWeek(context, today)
        val weekday = when (today.dayOfWeek) {
            DayOfWeek.MONDAY -> "周一"
            DayOfWeek.TUESDAY -> "周二"
            DayOfWeek.WEDNESDAY -> "周三"
            DayOfWeek.THURSDAY -> "周四"
            DayOfWeek.FRIDAY -> "周五"
            DayOfWeek.SATURDAY -> "周六"
            DayOfWeek.SUNDAY -> "周日"
        }
        val md = today.format(DateTimeFormatter.ofPattern("M.d"))
        return "$md   第${week}周   $weekday"
    }

    fun loadTodayCourses(context: Context): List<WidgetCourseInfo> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.timetable.cached_records", null) ?: return emptyList()

        val today = LocalDate.now()
        val currentWeek = computeCurrentWeek(context, today)
        val weekday = today.dayOfWeek.value

        return try {
            val arr = JSONArray(raw)
            val grouped = linkedMapOf<String, WidgetCourseInfo>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                if (obj.optBoolean("is_online", false)) continue
                if (obj.optInt("day_of_week", -1) != weekday) continue

                val weeks = obj.optJSONArray("week") ?: JSONArray()
                var hasCurrentWeek = false
                for (j in 0 until weeks.length()) {
                    if (weeks.optInt(j, -1) == currentWeek) {
                        hasCurrentWeek = true
                        break
                    }
                }
                if (!hasCurrentWeek) continue

                val periods = obj.optString("periods", "")
                val (startPeriod, endPeriod) = parsePeriods(periods)
                val isCurrent = isCurrentCourse(startPeriod, endPeriod)
                val courseName = obj.optString("course_name", "未命名课程").trim()
                val placeName = obj.optString("place_name", "地点待定")
                val teacher = obj.optString("teacher", "")
                val key = "$courseName|$startPeriod-$endPeriod"

                val existing = grouped[key]
                if (existing == null) {
                    grouped[key] = WidgetCourseInfo(
                        courseName = courseName,
                        placeName = placeName,
                        teacher = normalizeTeacherText(teacher),
                        startPeriod = startPeriod,
                        endPeriod = endPeriod,
                        isCurrent = isCurrent,
                    )
                } else {
                    grouped[key] = existing.copy(
                        placeName = if (existing.placeName.isBlank() || existing.placeName == "地点待定") placeName else existing.placeName,
                        teacher = mergeTeacherText(existing.teacher, teacher),
                        isCurrent = existing.isCurrent || isCurrent,
                    )
                }
            }
            grouped.values.sortedBy { it.startPeriod }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun teacherTokens(raw: String): List<String> {
        return raw.split(Regex("[、,，;；/\\s]+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    private fun normalizeTeacherText(raw: String): String {
        if (raw.isBlank()) return ""
        return teacherTokens(raw).distinct().joinToString("、")
    }

    private fun mergeTeacherText(existing: String, incoming: String): String {
        val ordered = linkedSetOf<String>()
        teacherTokens(existing).forEach { ordered += it }
        teacherTokens(incoming).forEach { ordered += it }
        return ordered.joinToString("、")
    }

    fun periodStartTime(period: Int): String {
        return periodTime[period]?.substringBefore('-') ?: "--:--"
    }

    fun periodEndTime(period: Int): String {
        return periodTime[period]?.substringAfter('-') ?: "--:--"
    }

    fun periodRangeText(startPeriod: Int, endPeriod: Int): String {
        val start = periodStartTime(startPeriod)
        val end = periodEndTime(endPeriod)
        return "$start\n$end"
    }

    private var flutterColorMap: Map<String, Int>? = null

    fun colorFor(context: Context, key: String): Int {
        val map = flutterColorMap ?: loadFlutterColors(context)
        return map[key] ?: defaultColor(key)
    }

    fun clearColorCache() {
        flutterColorMap = null
    }

    private fun loadFlutterColors(context: Context): Map<String, Int> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.timetable.course_colors", null)
        if (raw == null) {
            return emptyMap()
        }
        return try {
            val obj = JSONObject(raw)
            val map = mutableMapOf<String, Int>()
            for (name in obj.keys()) {
                val value = obj.getLong(name)
                map[name] = value.toInt()
            }
            flutterColorMap = map
            map
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private val defaultColors = intArrayOf(
        0xFF42A5F5.toInt(),
        0xFFE57373.toInt(),
        0xFF66BB6A.toInt(),
        0xFFFFA726.toInt(),
        0xFFAB47BC.toInt(),
        0xFF26C6DA.toInt(),
        0xFFFFCA28.toInt(),
        0xFF7E57C2.toInt(),
        0xFFEC407A.toInt(),
        0xFF8D6E63.toInt(),
        0xFF78909C.toInt(),
        0xFF5C6BC0.toInt(),
    )

    private fun defaultColor(key: String): Int {
        val idx = (key.hashCode() and Int.MAX_VALUE) % defaultColors.size
        return defaultColors[idx]
    }

    private fun computeCurrentWeek(context: Context, today: LocalDate): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.settings.term_start_date", null)
        val start = parseStartDate(raw) ?: LocalDate.of(today.year, 3, 2)
        val diffDays = ChronoUnit.DAYS.between(start, today).toInt()
        return if (diffDays < 0) 1 else (diffDays / 7) + 1
    }

    private fun parseStartDate(raw: String?): LocalDate? {
        if (raw.isNullOrBlank()) return null
        return try {
            LocalDate.parse(raw.take(10))
        } catch (_: Exception) {
            null
        }
    }

    private fun parsePeriods(raw: String): Pair<Int, Int> {
        val normalized = raw.replace("—", "-")
            .replace("－", "-")
            .replace("~", "-")
            .replace("到", "-")

        // 0) Full explicit forms: 第3节-第4节 / 第三节-第四节
        val fullNumRange = Regex("第\\s*(\\d{1,2})\\s*节\\s*-\\s*第\\s*(\\d{1,2})\\s*节").findAll(normalized).toList()
        if (fullNumRange.isNotEmpty()) {
            val m = fullNumRange.last()
            val s = m.groupValues[1].toIntOrNull()
            val e = m.groupValues[2].toIntOrNull()
            if (s != null && e != null && s in 1..12 && e in 1..12) {
                return if (s <= e) s to e else e to s
            }
        }

        val fullCnRange = Regex("第\\s*([一二三四五六七八九十]{1,3})\\s*节\\s*-\\s*第\\s*([一二三四五六七八九十]{1,3})\\s*节").findAll(normalized).toList()
        if (fullCnRange.isNotEmpty()) {
            val m = fullCnRange.last()
            val s = cnToNum(m.groupValues[1])
            val e = cnToNum(m.groupValues[2])
            if (s in 1..12 && e in 1..12) {
                return if (s <= e) s to e else e to s
            }
        }

        val rangeMatches = Regex("第?\\s*(\\d{1,2})\\s*-\\s*(\\d{1,2})\\s*节").findAll(normalized).toList()
        if (rangeMatches.isNotEmpty()) {
            val match = rangeMatches.last()
            val start = match.groupValues[1].toIntOrNull()
            val end = match.groupValues[2].toIntOrNull()
            if (start != null && end != null && start in 1..12 && end in 1..12) {
                return if (start <= end) start to end else end to start
            }
        }

        val cnRangeMatches = Regex("第?\\s*([一二三四五六七八九十]{1,3})\\s*-\\s*([一二三四五六七八九十]{1,3})\\s*节").findAll(normalized).toList()
        if (cnRangeMatches.isNotEmpty()) {
            val match = cnRangeMatches.last()
            val start = cnToNum(match.groupValues[1])
            val end = cnToNum(match.groupValues[2])
            if (start in 1..12 && end in 1..12) {
                return if (start <= end) start to end else end to start
            }
        }

        val singleMatches = Regex("第?\\s*(\\d{1,2})\\s*节").findAll(normalized).toList()
        if (singleMatches.isNotEmpty()) {
            val p = singleMatches.last().groupValues[1].toIntOrNull()
            if (p != null && p in 1..12) {
                return p to p
            }
        }

        val cnSingleMatches = Regex("第?\\s*([一二三四五六七八九十]{1,3})\\s*节").findAll(normalized).toList()
        if (cnSingleMatches.isNotEmpty()) {
            val p = cnToNum(cnSingleMatches.last().groupValues[1])
            if (p in 1..12) {
                return p to p
            }
        }

        val compactCn = Regex("([一二三四五六七八九十]{2,6})\\s*节").find(normalized)?.groupValues?.get(1)
        if (compactCn != null) {
            val nums = extractChinesePeriodNums(compactCn)
            if (nums.isNotEmpty()) {
                val start = nums.first()
                val end = nums.last()
                if (start in 1..12 && end in 1..12) {
                    return if (start <= end) start to end else end to start
                }
            }
        }

        val nums = Regex("\\d+").findAll(normalized).mapNotNull { it.value.toIntOrNull() }
            .filter { it in 1..12 }
            .toList()
        if (nums.isEmpty()) return 1 to 1
        if (nums.size == 1) return nums[0] to nums[0]
        val start = nums[nums.size - 2]
        val end = nums.last()
        return if (start <= end) start to end else end to start
    }

    private fun cnToNum(token: String): Int {
        return when (token) {
            "一" -> 1
            "二" -> 2
            "三" -> 3
            "四" -> 4
            "五" -> 5
            "六" -> 6
            "七" -> 7
            "八" -> 8
            "九" -> 9
            "十" -> 10
            "十一" -> 11
            "十二" -> 12
            else -> -1
        }
    }

    private fun extractChinesePeriodNums(compact: String): List<Int> {
        val result = mutableListOf<Int>()
        var i = 0
        while (i < compact.length) {
            val ch = compact[i]
            if (ch == '十') {
                if (i + 1 < compact.length && (compact[i + 1] == '一' || compact[i + 1] == '二')) {
                    result += if (compact[i + 1] == '一') 11 else 12
                    i += 2
                } else {
                    result += 10
                    i += 1
                }
                continue
            }

            val p = cnToNum(ch.toString())
            if (p in 1..9) {
                result += p
            }
            i += 1
        }
        return result.filter { it in 1..12 }
    }

    private fun isCurrentCourse(startPeriod: Int, endPeriod: Int): Boolean {
        val start = periodTime[startPeriod]?.substringBefore('-') ?: return false
        val end = periodTime[endPeriod]?.substringAfter('-') ?: return false
        val startTime = LocalTime.parse(start)
        val endTime = LocalTime.parse(end)
        val now = LocalDateTime.now().toLocalTime()
        return !now.isBefore(startTime) && !now.isAfter(endTime)
    }
}
