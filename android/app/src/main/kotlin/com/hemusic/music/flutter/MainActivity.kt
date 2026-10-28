package com.hemusic.music.flutter

import com.ryanheise.audioservice.AudioServiceActivity
import android.os.StatFs
import android.content.res.Configuration
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private var videoPip: VideoPictureInPictureHandler? = null
    private var localAudioQuery: LocalAudioQueryHandler? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        videoPip = VideoPictureInPictureHandler(this, messenger)
        localAudioQuery = LocalAudioQueryHandler(applicationContext, messenger)
        MethodChannel(
            messenger,
            "com.hemusic/audio_cache_capacity",
            io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        ).setMethodCallHandler { call, result ->
            if (call.method != "availableBytes") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = (call.arguments as? Map<*, *>)?.get("cachePath") as? String
            if (path.isNullOrBlank()) {
                result.error("invalid_path", "Cache directory is required", null)
                return@setMethodCallHandler
            }
            try {
                val directory = File(path).canonicalFile
                val cache = cacheDir.canonicalFile
                if (!directory.isDirectory ||
                    (directory != cache && !directory.path.startsWith(cache.path + File.separator))) {
                    result.error("invalid_path", "Not an application cache directory", null)
                } else {
                    result.success(StatFs(directory.path).availableBytes)
                }
            } catch (_: Exception) {
                result.error("capacity_unavailable", "Cache capacity is unavailable", null)
            }
        }
    }

    override fun onPictureInPictureModeChanged(active: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(active, newConfig)
        videoPip?.onModeChanged(active)
    }

    override fun onStop() {
        super.onStop()
        videoPip?.onStopped()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        localAudioQuery?.dispose()
        localAudioQuery = null
        videoPip?.dispose()
        videoPip = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
