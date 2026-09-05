package com.dagi.dagiplayer.dagiplayer

import android.app.PictureInPictureParams
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Rational
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val PIP_CHANNEL = "com.dagi.dagiplayer/pip"
    private val MEDIA_STORE_CHANNEL = "com.dagi.dagiplayer/media_store"
    private val MEDIA_INTENT_CHANNEL = "com.dagi.dagiplayer/media_intent"
    private val HEADSET_CHANNEL = "com.dagi.dagiplayer/headset"
    private val MEDIA_NOTIFICATION_CHANNEL = "com.dagi.dagiplayer/media_notification"

    private var pipChannel: MethodChannel? = null
    private var mediaIntentChannel: MethodChannel? = null
    private var headsetChannel: MethodChannel? = null
    private var mediaNotificationChannel: MethodChannel? = null
    private var pendingMediaIntent: Map<String, Any?>? = null

    private var isVideoPlaying = false
    private var autoPipEnabled = false
    private var pipAspectNumerator = 16
    private var pipAspectDenominator = 9

    private var isServiceBound = false
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            isServiceBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            isServiceBound = false
        }
    }

    override fun getInitialRoute(): String = "/splash"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        try {
            val serviceIntent = Intent(this, MediaNotificationService::class.java)
            bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)
        } catch (e: Throwable) {
            android.util.Log.e("MainActivity", "Failed to bind MediaNotificationService", e)
        }
    }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val mediaData = parseMediaIntent(intent)
        if (mediaData != null) {
            pendingMediaIntent = mediaData
            mediaIntentChannel?.invokeMethod("onMediaIntentReceived", mediaData)
        }
    }

    private fun handleIntent(intent: Intent?) {
        val mediaData = parseMediaIntent(intent)
        if (mediaData != null) {
            pendingMediaIntent = mediaData
        }
    }

    private fun parseMediaIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return null

        val data: Uri? = intent.data ?: intent.getParcelableExtra(Intent.EXTRA_STREAM)
        if (data == null) return null

        val uriStr = data.toString()
        val mimeType = intent.type ?: contentResolver.getType(data) ?: getMimeTypeFromUri(data)

        val isVideo = mimeType?.startsWith("video/") == true || isVideoExtension(uriStr)
        val isAudio = mimeType?.startsWith("audio/") == true || isAudioExtension(uriStr)

        if (!isVideo && !isAudio) return null

        val displayName = getFileName(data) ?: (if (isVideo) "Video File" else "Audio File")

        return mapOf(
            "uri" to uriStr,
            "type" to (if (isVideo) "video" else "audio"),
            "mimeType" to (mimeType ?: (if (isVideo) "video/*" else "audio/*")),
            "title" to displayName
        )
    }

    private fun getFileName(uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) {
                            result = cursor.getString(index)
                        }
                    }
                }
            } catch (_: Throwable) {}
        }
        if (result == null) {
            val path = uri.path
            val cut = path?.lastIndexOf('/') ?: -1
            if (cut != -1) {
                result = path?.substring(cut + 1)
            }
        }
        return result
    }

    private fun isAudioExtension(path: String): Boolean {
        val lower = path.lowercase()
        return lower.endsWith(".mp3") || lower.endsWith(".m4a") || lower.endsWith(".wav") ||
                lower.endsWith(".flac") || lower.endsWith(".aac") || lower.endsWith(".ogg") ||
                lower.endsWith(".wma") || lower.endsWith(".opus")
    }

    private fun isVideoExtension(path: String): Boolean {
        val lower = path.lowercase()
        return lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".webm") ||
                lower.endsWith(".avi") || lower.endsWith(".mov") || lower.endsWith(".3gp") ||
                lower.endsWith(".ts") || lower.endsWith(".flv")
    }

    private fun getMimeTypeFromUri(uri: Uri): String? {
        val path = uri.path ?: return null
        val lower = path.lowercase()
        return when {
            isAudioExtension(lower) -> "audio/*"
            isVideoExtension(lower) -> "video/*"
            else -> null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Media Intent Channel
        mediaIntentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_INTENT_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialMediaIntent" -> {
                        val media = pendingMediaIntent
                        pendingMediaIntent = null
                        result.success(media)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // PiP Method Channel
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPip" -> {
                        val num = call.argument<Int>("aspectRatioX") ?: 16
                        val den = call.argument<Int>("aspectRatioY") ?: 9
                        val entered = enterPipInternal(num, den)
                        result.success(entered)
                    }
                    "setAutoPip" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val num = call.argument<Int>("aspectRatioX") ?: 16
                        val den = call.argument<Int>("aspectRatioY") ?: 9
                        autoPipEnabled = enabled
                        isVideoPlaying = enabled
                        pipAspectNumerator = num
                        pipAspectDenominator = den
                        updateAutoPipParams(enabled, num, den)
                        result.success(true)
                    }
                    "isPipSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Native MediaStore Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_STORE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAudioList" -> {
                        Thread {
                            try {
                                val audioList = queryAudioFromMediaStore()
                                runOnUiThread { result.success(audioList) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("QUERY_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "getVideoList" -> {
                        Thread {
                            try {
                                val videoList = queryVideosFromMediaStore()
                                runOnUiThread { result.success(videoList) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("QUERY_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "getVideoThumbnail" -> {
                        val uriStr = call.argument<String>("uri")
                        val width = call.argument<Int>("width") ?: 360
                        val height = call.argument<Int>("height") ?: 240
                        Thread {
                            try {
                                val bytes = extractVideoThumbnail(uriStr, width, height)
                                runOnUiThread { result.success(bytes) }
                            } catch (e: Exception) {
                                runOnUiThread { result.success(null) }
                            }
                        }.start()
                    }
                    "getAudioArtwork" -> {
                        val uriStr = call.argument<String>("uri")
                        val albumId = call.argument<Number>("albumId")?.toLong()
                        Thread {
                            try {
                                val bytes = extractAudioArtwork(uriStr, albumId)
                                runOnUiThread { result.success(bytes) }
                            } catch (e: Exception) {
                                runOnUiThread { result.success(null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Headset / Earphone Hardware Media Button Channel
        headsetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEADSET_CHANNEL)

        // Quick Panel Media Notification Channel
        mediaNotificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_NOTIFICATION_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateNotification" -> {
                        try {
                            val title = call.argument<String>("title") ?: "Unknown Title"
                            val artist = call.argument<String>("artist") ?: "Unknown Artist"
                            val album = call.argument<String>("album")
                            val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                            val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                            val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                            val artworkBytes = call.argument<ByteArray>("artworkBytes")

                            val data = MediaNotificationService.MediaData(
                                title = title,
                                artist = artist,
                                album = album,
                                isPlaying = isPlaying,
                                positionMs = positionMs,
                                durationMs = durationMs,
                                artworkBytes = artworkBytes
                            )
                            MediaNotificationService.update(applicationContext, data)
                            result.success(true)
                        } catch (e: Throwable) {
                            android.util.Log.e("MainActivity", "Error in updateNotification", e)
                            result.success(false)
                        }
                    }
                    "hideNotification" -> {
                        try {
                            MediaNotificationService.stop(applicationContext)
                            result.success(true)
                        } catch (e: Throwable) {
                            android.util.Log.e("MainActivity", "Error in hideNotification", e)
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MediaNotificationService.listener = object : MediaNotificationService.MediaActionListener {
            override fun onPlay() {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "play")) }
            }

            override fun onPause() {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "pause")) }
            }

            override fun onPlayPause() {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "toggle")) }
            }

            override fun onNext() {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "next")) }
            }

            override fun onPrevious() {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "previous")) }
            }

            override fun onSeek(positionMs: Long) {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "seek", "positionMs" to positionMs)) }
            }

            override fun onStop() {
                runOnUiThread { mediaNotificationChannel?.invokeMethod("onAction", mapOf("action" to "stop")) }
            }
        }

        // Native HTTP Channel for robust lyrics and metadata fetching
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dagi.dagiplayer/http").setMethodCallHandler { call, result ->
            when (call.method) {
                "get" -> {
                    val urlStr = call.argument<String>("url")
                    if (urlStr.isNullOrEmpty()) {
                        result.error("INVALID_URL", "URL cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val url = java.net.URL(urlStr)
                            val cm = getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
                            val network = cm?.activeNetwork
                            val conn = ((network?.openConnection(url) ?: url.openConnection()) as java.net.HttpURLConnection).apply {
                                requestMethod = "GET"
                                connectTimeout = 7000
                                readTimeout = 7000
                                setRequestProperty("User-Agent", "DagiPlayer/1.0 (https://github.com/dagiplayer)")
                                setRequestProperty("Accept", "application/json")
                            }
                            val code = conn.responseCode
                            if (code in 200..299) {
                                val body = conn.inputStream.bufferedReader().use { it.readText() }
                                runOnUiThread { result.success(body) }
                                return@Thread
                            }
                        } catch (_: Throwable) {}

                        // Fallback 1: Try all available internet-capable network interfaces
                        try {
                            val cm = getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
                            if (cm != null) {
                                for (net in cm.allNetworks) {
                                    val caps = cm.getNetworkCapabilities(net)
                                    if (caps != null && caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                                        try {
                                            val url = java.net.URL(urlStr)
                                            val conn = (net.openConnection(url) as java.net.HttpURLConnection).apply {
                                                requestMethod = "GET"
                                                connectTimeout = 6000
                                                readTimeout = 6000
                                                setRequestProperty("User-Agent", "DagiPlayer/1.0 (https://github.com/dagiplayer)")
                                                setRequestProperty("Accept", "application/json")
                                            }
                                            val code = conn.responseCode
                                            if (code in 200..299) {
                                                val body = conn.inputStream.bufferedReader().use { it.readText() }
                                                runOnUiThread { result.success(body) }
                                                return@Thread
                                            }
                                        } catch (_: Throwable) {}
                                    }
                                }
                            }
                        } catch (_: Throwable) {}

                        // Fallback 2: Direct Cloudflare edge IP fallback for lrclib.net (bypasses carrier DNS failure)
                        if (urlStr.contains("lrclib.net")) {
                            try {
                                val ipUrlStr = urlStr.replace("https://lrclib.net", "https://172.67.167.238")
                                val ipUrl = java.net.URL(ipUrlStr)
                                val ipConn = (ipUrl.openConnection() as javax.net.ssl.HttpsURLConnection).apply {
                                    requestMethod = "GET"
                                    connectTimeout = 6000
                                    readTimeout = 6000
                                    setRequestProperty("Host", "lrclib.net")
                                    setRequestProperty("User-Agent", "DagiPlayer/1.0 (https://github.com/dagiplayer)")
                                    setRequestProperty("Accept", "application/json")
                                    hostnameVerifier = javax.net.ssl.HostnameVerifier { _, _ -> true }
                                }
                                val code = ipConn.responseCode
                                if (code in 200..299) {
                                    val body = ipConn.inputStream.bufferedReader().use { it.readText() }
                                    runOnUiThread { result.success(body) }
                                    return@Thread
                                }
                            } catch (_: Throwable) {}
                        }

                        runOnUiThread { result.success(null) }
                    }.start()
                }
            }
        }

        // Native URL Launcher Channel for developer website and external links
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dagi.dagiplayer/launcher").setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val urlStr = call.argument<String>("url")
                    if (urlStr != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(urlStr)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        // Keep MediaNotificationService.listener intact so background/lockscreen controls continue working
        if (isServiceBound) {
            try {
                unbindService(serviceConnection)
                isServiceBound = false
            } catch (_: Throwable) {}
        }
        super.onDestroy()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
            KeyEvent.KEYCODE_MEDIA_STOP,
            KeyEvent.KEYCODE_MEDIA_NEXT,
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                val action = when (keyCode) {
                    KeyEvent.KEYCODE_MEDIA_STOP, KeyEvent.KEYCODE_MEDIA_PAUSE -> "stop"
                    KeyEvent.KEYCODE_MEDIA_PLAY -> "play"
                    KeyEvent.KEYCODE_MEDIA_NEXT -> "next"
                    KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "previous"
                    else -> "toggle"
                }
                headsetChannel?.invokeMethod("onMediaButton", mapOf("action" to action))
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun enterPipInternal(aspectX: Int, aspectY: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val hasPip = packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
            if (hasPip) {
                try {
                    val rational = Rational(aspectX.coerceIn(1, 239), aspectY.coerceIn(1, 239))
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(rational)
                        .build()
                    return enterPictureInPictureMode(params)
                } catch (e: Exception) {
                    return false
                }
            }
        }
        return false
    }

    private fun updateAutoPipParams(enabled: Boolean, aspectX: Int, aspectY: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val rational = Rational(aspectX.coerceIn(1, 239), aspectY.coerceIn(1, 239))
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .setAutoEnterEnabled(enabled)
                setPictureInPictureParams(builder.build())
            } catch (_: Exception) {}
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoPipEnabled && isVideoPlaying && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPipInternal(pipAspectNumerator, pipAspectDenominator)
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    private fun extractVideoThumbnail(uriStr: String?, width: Int, height: Int): ByteArray? {
        if (uriStr.isNullOrEmpty()) return null
        try {
            val uri = if (uriStr.startsWith("content://")) {
                Uri.parse(uriStr)
            } else {
                Uri.fromFile(File(uriStr))
            }

            var bitmap: Bitmap? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    bitmap = contentResolver.loadThumbnail(uri, Size(width, height), null)
                } catch (_: Throwable) {}
            }

            if (bitmap == null) {
                val retriever = MediaMetadataRetriever()
                try {
                    if (uriStr.startsWith("content://")) {
                        retriever.setDataSource(this, uri)
                    } else {
                        retriever.setDataSource(uriStr)
                    }
                    bitmap = retriever.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        ?: retriever.frameAtTime
                } catch (_: Throwable) {
                } finally {
                    try { retriever.release() } catch (_: Throwable) {}
                }
            }

            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                return stream.toByteArray()
            }
        } catch (e: Throwable) {
            e.printStackTrace()
        }
        return null
    }

    private fun extractAudioArtwork(uriStr: String?, albumId: Long?): ByteArray? {
        try {
            // 1. If albumId is provided, try album art Uri
            if (albumId != null && albumId > 0) {
                val albumArtUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)
                try {
                    contentResolver.openInputStream(albumArtUri)?.use { input ->
                        val bytes = input.readBytes()
                        if (bytes.isNotEmpty()) return bytes
                    }
                } catch (_: Throwable) {}
            }

            // 2. Try loading thumbnail or embedded ID3 picture from song URI
            if (!uriStr.isNullOrEmpty()) {
                val uri = if (uriStr.startsWith("content://")) {
                    Uri.parse(uriStr)
                } else {
                    Uri.fromFile(File(uriStr))
                }

                if (uriStr.contains("albumart")) {
                    try {
                        contentResolver.openInputStream(uri)?.use { input ->
                            val bytes = input.readBytes()
                            if (bytes.isNotEmpty()) return bytes
                        }
                    } catch (_: Throwable) {}
                }

                // Load thumbnail using ContentResolver on Android 10+ (API 29+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !uriStr.contains("albumart")) {
                    try {
                        val bitmap = contentResolver.loadThumbnail(uri, Size(500, 500), null)
                        val stream = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                        val bytes = stream.toByteArray()
                        if (bytes.isNotEmpty()) return bytes
                    } catch (_: Throwable) {}
                }

                // Extract embedded picture via MediaMetadataRetriever
                if (!uriStr.contains("albumart")) {
                    val retriever = MediaMetadataRetriever()
                    try {
                        if (uriStr.startsWith("content://")) {
                            retriever.setDataSource(this, uri)
                        } else {
                            retriever.setDataSource(uriStr)
                        }
                        val art = retriever.embeddedPicture
                        if (art != null && art.isNotEmpty()) return art
                    } catch (_: Throwable) {
                    } finally {
                        try { retriever.release() } catch (_: Throwable) {}
                    }
                }
            }
        } catch (e: Throwable) {
            e.printStackTrace()
        }
        return null
    }

    private fun queryAudioFromMediaStore(): List<Map<String, Any?>> {
        val audioList = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.ALBUM_ID
        )

        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        try {
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val title = cursor.getString(titleCol) ?: "Unknown Title"
                    val artist = cursor.getString(artistCol) ?: "Unknown Artist"
                    val album = cursor.getString(albumCol) ?: "Unknown Album"
                    val rawPath = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id).toString()
                    val duration = cursor.getLong(durationCol)
                    val size = cursor.getLong(sizeCol)
                    val dateAdded = cursor.getLong(dateCol)
                    val albumId = cursor.getLong(albumIdCol)

                    audioList.add(mapOf(
                        "id" to "media-$id",
                        "title" to title,
                        "artist" to (if (artist == "<unknown>") "Unknown Artist" else artist),
                        "album" to (if (album == "<unknown>") "Unknown Album" else album),
                        "uri" to contentUri,
                        "path" to (rawPath ?: contentUri),
                        "durationMs" to duration,
                        "size" to size,
                        "dateAdded" to dateAdded,
                        "albumId" to albumId,
                        "artworkUri" to contentUri
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return audioList
    }

    private fun queryVideosFromMediaStore(): List<Map<String, Any?>> {
        val videoList = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT
        )

        val sortOrder = "${MediaStore.Video.Media.DATE_ADDED} DESC"

        try {
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
                val dataCol = cursor.getColumnIndex(MediaStore.Video.Media.DATA)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
                val widthCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
                val heightCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val title = cursor.getString(titleCol) ?: "Video"
                    val rawPath = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val contentUri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id).toString()
                    val duration = cursor.getLong(durationCol)
                    val size = cursor.getLong(sizeCol)
                    val dateAdded = cursor.getLong(dateCol)
                    val width = cursor.getInt(widthCol)
                    val height = cursor.getInt(heightCol)

                    videoList.add(mapOf(
                        "id" to "media-vid-$id",
                        "title" to title,
                        "uri" to contentUri,
                        "path" to (rawPath ?: contentUri),
                        "durationMs" to duration,
                        "size" to size,
                        "dateAdded" to dateAdded,
                        "width" to width,
                        "height" to height
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return videoList
    }
}
