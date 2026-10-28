package com.flux.studentplanner

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
import org.json.JSONArray
import org.json.JSONObject
import java.util.TimeZone

object ReminderScheduler {
    private const val CHANNEL = "academic_reminders"
    private fun prefs(c: Context) = c.getSharedPreferences("flux_alarm_plans", Context.MODE_PRIVATE)
    private fun manager(c: Context) = c.getSystemService(NotificationManager::class.java)
    fun initialize(c: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(c).createNotificationChannel(NotificationChannel(CHANNEL, "Academic reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Local reminders 30 minutes before assignments and exams"
            })
        }
    }
    fun permitted(c: Context): Boolean = manager(c).areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 26 || manager(c).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE) &&
        (Build.VERSION.SDK_INT < 33 || c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
    fun precise(c: Context): Boolean = Build.VERSION.SDK_INT < 31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    private fun plans(c: Context): JSONArray = JSONArray(prefs(c).getString("plans", "[]"))
    private fun alarm(c: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(c, id,
        Intent(c, ReminderReceiver::class.java).setAction("com.flux.studentplanner.REMINDER").putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun replace(c: Context, enabled: Boolean, next: JSONArray) {
        // Validate every plan before changing any persisted alarm state.
        for (i in 0 until next.length()) {
            val r = next.getJSONObject(i)
            require(r.getInt("id") > 0 && r.getString("title").isNotBlank())
            ReminderTime.triggerMillis(r.getString("date"), r.getInt("minute"), TimeZone.getDefault().id)
        }
        val previous = plans(c)
        check(prefs(c).edit().putString("plans", next.toString()).putBoolean("enabled", enabled).commit()) { "Cannot save reminder plans" }
        val alarms = c.getSystemService(AlarmManager::class.java)
        for (i in 0 until previous.length()) {
            val id = previous.getJSONObject(i).getInt("id")
            alarms.cancel(alarm(c, id))
            manager(c).cancel(id)
        }
        reschedule(c)
    }
    fun reschedule(c: Context) {
        initialize(c)
        val alarms = c.getSystemService(AlarmManager::class.java)
        val rows = plans(c)
        for (i in 0 until rows.length()) {
            val r = rows.getJSONObject(i)
            val id = r.getInt("id")
            val intent = alarm(c, id)
            alarms.cancel(intent)
            if (!prefs(c).getBoolean("enabled", true) || !permitted(c)) continue
            val whenMillis = ReminderTime.triggerMillis(r.getString("date"), r.getInt("minute"), TimeZone.getDefault().id)
            if (prefs(c).getString("delivered_$id", null) == signature(r)) continue
            if (whenMillis <= System.currentTimeMillis()) {
                // A newly saved deadline inside the lead window gets one useful
                // immediate reminder, rather than silently missing its reminder.
                if (whenMillis + 30 * 60 * 1000L > System.currentTimeMillis()) deliver(c, id)
                continue
            }
            if (precise(c)) {
                try { alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, intent) }
                catch (_: SecurityException) { alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, intent) }
            } else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, intent)
        }
    }
    fun pending(c: Context): Int {
        if (!prefs(c).getBoolean("enabled", true) || !permitted(c)) return 0
        val rows = plans(c)
        return (0 until rows.length()).count {
            val r = rows.getJSONObject(it)
            ReminderTime.triggerMillis(r.getString("date"), r.getInt("minute"), TimeZone.getDefault().id) > System.currentTimeMillis() &&
                prefs(c).getString("delivered_${r.getInt("id")}", null) != signature(r)
        }
    }
    private fun signature(r: JSONObject) = "${r.getString("date")}/${r.getInt("minute") }"
    fun deliver(c: Context, id: Int) {
        if (!prefs(c).getBoolean("enabled", true) || !permitted(c)) return
        val rows = plans(c)
        val r = (0 until rows.length()).map { rows.getJSONObject(it) }.firstOrNull { it.getInt("id") == id } ?: return
        val expected = ReminderTime.triggerMillis(r.getString("date"), r.getInt("minute"), TimeZone.getDefault().id)
        // Ignore stale broadcasts after an edit or clock change. Rebuild the future alarm instead.
        if (expected > System.currentTimeMillis()) { reschedule(c); return }
        if (expected + 30 * 60 * 1000L <= System.currentTimeMillis()) return
        if (prefs(c).getString("delivered_$id", null) == signature(r)) return
        val open = PendingIntent.getActivity(c, id, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        val dueMinute = r.getInt("minute")
        val dueTime = "%02d:%02d".format(dueMinute / 60, dueMinute % 60)
        val notification = builder.setSmallIcon(com.flux.studentplanner.R.drawable.ic_notification)
            .setContentTitle(r.getString("title"))
            .setContentText("${r.getString("kind")} due at $dueTime · ${r.getString("date")}")
            .setContentIntent(open).setAutoCancel(true).setShowWhen(true).build()
        manager(c).notify(id, notification)
        prefs(c).edit().putString("delivered_$id", signature(r)).apply()
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { ReminderScheduler.deliver(context, intent.getIntExtra("id", -1)) }
        catch (e: Exception) { context.getSharedPreferences("flux_alarm_plans", Context.MODE_PRIVATE).edit().putString("lastError", e.toString()).apply() }
    }
}
class ReminderClockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED, AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) return
        try { ReminderScheduler.reschedule(context) }
        catch (e: Exception) { context.getSharedPreferences("flux_alarm_plans", Context.MODE_PRIVATE).edit().putString("lastError", e.toString()).apply() }
    }
}
