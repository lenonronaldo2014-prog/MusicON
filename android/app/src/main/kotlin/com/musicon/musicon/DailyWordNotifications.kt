package com.musicon.musicon

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar
import kotlin.random.Random

object DailyWordNotifications {
    const val ACTION_DELIVER = "com.musicon.musicon.DAILY_WORD"
    const val CHANNEL_ID = "com.musicon.musicon.daily_word"
    private const val NOTIFICATION_ID = 8001
    private fun prefs(context: Context) = context.getSharedPreferences("daily_word", Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    fun enabled(context: Context) = prefs(context).getBoolean("enabled", true)

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(context).createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "Palavra do dia", NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "Uma mensagem de fé, motivação ou reflexão, por volta das 8h." })
        }
    }

    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (!manager(context).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 || manager(context).getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        check(prefs(context).edit().putBoolean("enabled", enabled).commit())
        if (!enabled) manager(context).cancel(NOTIFICATION_ID)
        schedule(context)
    }

    fun state(context: Context, now: Long = System.currentTimeMillis()): Map<String, Any> {
        createChannel(context)
        val preferences = prefs(context)
        if (!preferences.contains("seed")) {
            check(preferences.edit().putInt("seed", Random.nextInt()).commit())
        }
        val word = DailyWordContent.forDay(now, preferences.getInt("seed", 0))
        return mapOf(
            "enabled" to enabled(context), "allowed" to allowed(context),
            "text" to word.text, "category" to word.category, "reference" to word.reference,
            "date" to DailyWordContent.dateKey(now)
        )
    }

    fun schedule(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(context, NOTIFICATION_ID,
            Intent(context, DailyWordReceiver::class.java).setAction(ACTION_DELIVER),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (!enabled(context) || !allowed(context)) {
            alarm.cancel(pending)
            return
        }
        val now = System.currentTimeMillis()
        val preferences = prefs(context)
        val previous = preferences.getLong("scheduled_for", 0)
        val today = DailyWordContent.dateKey(now)
        // Preserve an overdue morning alarm when the app resumes before delivery.
        val overdue = previous > 0 && previous <= now &&
            DailyWordContent.dateKey(previous) == today &&
            preferences.getString("last_delivered", null) != today &&
            Calendar.getInstance().get(Calendar.HOUR_OF_DAY) < 10
        val next = if (overdue) now + 60_000 else DailyWordContent.nextMorning(now)
        check(preferences.edit().putLong("scheduled_for", next).commit())
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
    }

    fun deliver(context: Context, now: Long = System.currentTimeMillis()) {
        if (!enabled(context) || !allowed(context)) return
        val today = DailyWordContent.dateKey(now)
        val preferences = prefs(context)
        if (preferences.getString("last_delivered", null) == today) return
        // Do not deliver an old alarm in the middle of the night after a clock change.
        if (Calendar.getInstance().apply { timeInMillis = now }.get(Calendar.HOUR_OF_DAY) !in 8..10) return
        val word = state(context, now)
        val content = listOf(word["text"], word["reference"]).filter { it != "" }.joinToString("\n")
        val launch = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("daily_word", true)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle("Palavra do dia • ${word["category"]}")
            .setContentText(word["text"] as String)
            .setStyle(Notification.BigTextStyle().bigText(content))
            .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_RECOMMENDATION)
            .setVisibility(Notification.VISIBILITY_PUBLIC).build()
        try {
            manager(context).notify(NOTIFICATION_ID, notification)
            check(preferences.edit().putString("last_delivered", today).commit())
        } catch (_: SecurityException) {
            // Permission may be revoked between the check and notify().
        }
    }
}

class DailyWordReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DailyWordNotifications.createChannel(context)
        if (intent.action == DailyWordNotifications.ACTION_DELIVER) DailyWordNotifications.deliver(context)
        DailyWordNotifications.schedule(context)
    }
}
