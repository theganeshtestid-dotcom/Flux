package com.flux.studentplanner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flux/reminders").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initialize" -> { ReminderScheduler.initialize(this); result.success(null) }
                    "status" -> result.success(mapOf("permitted" to ReminderScheduler.permitted(this), "precise" to ReminderScheduler.precise(this), "pending" to ReminderScheduler.pending(this), "lastError" to getSharedPreferences("flux_alarm_plans", MODE_PRIVATE).getString("lastError", null)))
                    "replace" -> {
                        val rows = call.argument<List<Map<String, Any?>>>("plans") ?: emptyList()
                        val json = JSONArray()
                        rows.forEach { json.put(JSONObject(it)) }
                        ReminderScheduler.replace(this, call.argument<Boolean>("enabled") == true, json)
                        result.success(null)
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) result.error("busy", "Permission request already open", null)
                            else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4030) }
                        } else {
                            if (!ReminderScheduler.permitted(this)) startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(ReminderScheduler.permitted(this))
                        }
                    }
                    "ackError" -> { getSharedPreferences("flux_alarm_plans", MODE_PRIVATE).edit().remove("lastError").apply(); result.success(null) }
                    "requestPrecision" -> {
                        if (Build.VERSION.SDK_INT >= 31 && !ReminderScheduler.precise(this)) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("reminder_error", e.message, null) }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4030) { permissionResult?.success(ReminderScheduler.permitted(this)); permissionResult = null }
    }
}
