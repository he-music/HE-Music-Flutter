package com.hemusic.music.flutter

import android.content.Context
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Query indexed audio in one operation, including the incremental-scan fingerprint. */
class LocalAudioQueryHandler(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(
        messenger,
        "com.hemusic/local_audio_query",
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue()
    )

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "scanSongs") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val projection = arrayOf(
                    MediaStore.Audio.Media._ID,
                    MediaStore.Audio.Media.TITLE,
                    MediaStore.Audio.Media.ARTIST,
                    MediaStore.Audio.Media.ALBUM,
                    MediaStore.Audio.Media.DURATION,
                    MediaStore.Audio.Media.DATA,
                    MediaStore.Audio.Media.MIME_TYPE,
                    MediaStore.Audio.Media.SIZE,
                    MediaStore.Audio.Media.DATE_MODIFIED
                )
                val tracks = mutableListOf<Map<String, Any?>>()
                val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
                    "${MediaStore.Audio.Media.DATA} NOT LIKE ? AND " +
                    "${MediaStore.Audio.Media.DATA} NOT LIKE ?"
                val cursor = context.contentResolver.query(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    arrayOf("%/WhatsApp/%", "%/Call/%"),
                    null
                ) ?: throw IllegalStateException("MediaStore query returned no cursor")
                cursor.use {
                    while (it.moveToNext()) {
                        tracks.add(mapOf(
                            "id" to it.getLong(0).toString(),
                            "title" to it.getString(1),
                            "artist" to it.getString(2),
                            "album" to it.getString(3),
                            "duration" to it.getLong(4),
                            "filePath" to it.getString(5),
                            "mimeType" to it.getString(6),
                            "size" to it.getLong(7),
                            "modifiedAt" to if (it.isNull(8) || it.getLong(8) <= 0) null
                                else it.getLong(8) * 1000L
                        ))
                    }
                }
                result.success(tracks)
            } catch (error: Exception) {
                result.error("scan_failed", error.message, null)
            }
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)
}
