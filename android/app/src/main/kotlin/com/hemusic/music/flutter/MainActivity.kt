package com.hemusic.music.flutter

import com.ryanheise.audioservice.AudioServiceActivity
import android.os.StatFs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
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
}
