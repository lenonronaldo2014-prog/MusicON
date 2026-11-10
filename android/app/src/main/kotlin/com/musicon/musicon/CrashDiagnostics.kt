// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.musicon

import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

class MusicOnApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                CrashDiagnostics.record(this, "android", error.javaClass.name,
                    error.stackTrace.take(16).map { "${it.className}.${it.methodName}(${it.fileName}:${it.lineNumber})" })
            } catch (_: Throwable) { /* Preserve Android's original crash handler. */ }
            if (previous != null) previous.uncaughtException(thread, error)
            else { android.os.Process.killProcess(android.os.Process.myPid()); kotlin.system.exitProcess(10) }
        }
    }
}

/** Local-only diagnostics. Exception messages, URLs, tokens and user files are excluded. */
object CrashDiagnostics {
    private const val PREFS = "musicon_diagnostics"
    private var lastSignature = ""
    private var lastTime = 0L

    @Synchronized fun record(context: Context, source: String, type: String, frames: List<String>) {
        if (source !in setOf("android", "flutter", "dart")) return
        val signature = "$source:$type"
        val now = android.os.SystemClock.elapsedRealtime()
        if (signature == lastSignature && now - lastTime < 10000L) return
        lastSignature = signature; lastTime = now
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = try { JSONArray(prefs.getString("events", "[]")) } catch (_: Exception) { JSONArray() }
        val events = JSONArray()
        for (i in maxOf(0, old.length() - 7) until old.length()) events.put(old.getJSONObject(i))
        val safeFrames = JSONArray()
        frames.take(16).forEach { frame ->
            // Only code locations; never retain exception text or a network URL.
            if (!frame.contains("://") && frame.matches(Regex("[A-Za-z0-9_.$<>:/() #@+\\-]+"))) {
                safeFrames.put(frame.take(240))
            }
        }
        @Suppress("DEPRECATION")
        val version = context.packageManager.getPackageInfo(context.packageName, 0).versionName
        events.put(JSONObject().put("time", System.currentTimeMillis()).put("version", version)
            .put("source", source).put("type", type.replace(Regex("[^A-Za-z0-9_.$<>]"), "").take(100))
            .put("frames", safeFrames))
        prefs.edit().putString("events", events.toString()).commit()
    }

    fun report(context: Context): String {
        @Suppress("DEPRECATION")
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        @Suppress("DEPRECATION")
        val build = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        val report = JSONObject().put("format", 1).put("app", "MusicON").put("version", info.versionName)
            .put("build", build).put("androidApi", Build.VERSION.SDK_INT)
            .put("manufacturer", Build.MANUFACTURER).put("model", Build.MODEL)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        report.put("errors", try { JSONArray(prefs.getString("events", "[]")) } catch (_: Exception) { JSONArray() })
        val exits = JSONArray()
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                manager.getHistoricalProcessExitReasons(context.packageName, 0, 5).forEach { exit ->
                    exits.put(JSONObject().put("time", exit.timestamp).put("reason", exit.reason)
                        .put("kind", exitReason(exit.reason)).put("status", exit.status)
                        .put("importance", exit.importance).put("memoryKb", exit.pss))
                }
            } catch (_: Exception) { report.put("exitHistory", "unavailable") }
        } else report.put("exitHistory", "requires_android_11")
        report.put("exits", exits)
        return report.toString(2)
    }

    private fun exitReason(reason: Int): String = when (reason) {
        1 -> "app_exit"
        2 -> "signal"
        3 -> "low_memory"
        4 -> "java_crash"
        5 -> "native_crash"
        6 -> "not_responding"
        7 -> "initialization_failure"
        8 -> "permission_change"
        9 -> "resource_usage"
        10 -> "user_requested"
        11 -> "user_stopped"
        12 -> "dependency_changed"
        14 -> "freezer"
        15 -> "package_changed"
        16 -> "package_updated"
        else -> "other"
    }
}
