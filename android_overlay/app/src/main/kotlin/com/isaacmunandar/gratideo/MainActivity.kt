package com.isaacmunandar.gratideo

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends AudioServiceActivity so the soundscape keeps playing in the background
 * (just_audio_background). Adds the "gratideo/focus" channel for Do Not Disturb
 * during Selah: the user grants access once in system settings, then the app can
 * silence everything except alarms for the session and restore it on Amen.
 */
class MainActivity : AudioServiceActivity() {
    private val channelName = "gratideo/focus"
    private var previousFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && nm.isNotificationPolicyAccessGranted
                )
                "requestAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                    }
                    result.success(null)
                }
                "setQuiet" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || !nm.isNotificationPolicyAccessGranted) {
                        result.error("NO_ACCESS", "Do Not Disturb access not granted", null)
                    } else {
                        val on = call.argument<Boolean>("on") ?: false
                        if (on) {
                            previousFilter = nm.currentInterruptionFilter
                            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
                        } else {
                            nm.setInterruptionFilter(
                                if (previousFilter == NotificationManager.INTERRUPTION_FILTER_ALARMS) NotificationManager.INTERRUPTION_FILTER_ALL else previousFilter
                            )
                        }
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
