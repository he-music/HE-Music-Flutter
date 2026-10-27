package com.hemusic.music.flutter

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** PiP keeps the existing Flutter video texture and playback session alive. */
class VideoPictureInPictureHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "com.hemusic/video_pip")
    private val action = "${activity.packageName}.VIDEO_PIP_TOGGLE"
    private var registered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == action) channel.invokeMethod("togglePlayback", null)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "enter", "update" -> {
                    if (!isSupported()) {
                        result.success(false)
                    } else {
                        try {
                            val ratio = (call.argument<Number>("aspectRatio")?.toDouble() ?: (16.0 / 9.0))
                                .takeIf { it.isFinite() && it > 0 } ?: (16.0 / 9.0)
                            val playing = call.argument<Boolean>("playing") ?: false
                            val params = params(ratio, playing)
                            if (call.method == "enter") {
                                registerReceiver()
                                result.success(activity.enterPictureInPictureMode(params))
                            } else {
                                activity.setPictureInPictureParams(params)
                                result.success(true)
                            }
                        } catch (_: Exception) {
                            result.error("pip_unavailable", "Unable to enter picture in picture", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    @android.annotation.TargetApi(Build.VERSION_CODES.O)
    private fun params(ratio: Double, playing: Boolean): PictureInPictureParams {
        // Android limits PiP aspect ratios to [1/2.39, 2.39].
        val safeRatio = ratio.coerceIn(1.0 / 2.38, 2.38)
        val intent = Intent(action).setPackage(activity.packageName)
        val pending = PendingIntent.getBroadcast(activity, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val label = activity.getString(if (playing) R.string.video_pip_pause else R.string.video_pip_play)
        val icon = Icon.createWithResource(activity,
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational((safeRatio * 10000).toInt(), 10000))
            .setActions(listOf(RemoteAction(icon, label, label, pending)))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setSeamlessResizeEnabled(true)
            // PiP is entered explicitly via the player button, never on Home.
            builder.setAutoEnterEnabled(false)
        }
        return builder.build()
    }

    private fun registerReceiver() {
        if (registered) return
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            activity.registerReceiver(receiver, filter)
        }
        registered = true
    }

    fun onModeChanged(active: Boolean) {
        channel.invokeMethod("modeChanged", active)
    }

    fun onStopped() {
        channel.invokeMethod("stopped", null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        if (registered) activity.unregisterReceiver(receiver)
        registered = false
    }
}
