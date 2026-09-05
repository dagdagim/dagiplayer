package com.dagi.dagiplayer.dagiplayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle

class MediaNotificationService : Service() {

    interface MediaActionListener {
        fun onPlay()
        fun onPause()
        fun onPlayPause()
        fun onNext()
        fun onPrevious()
        fun onSeek(positionMs: Long)
        fun onStop()
    }

    data class MediaData(
        val title: String,
        val artist: String,
        val album: String?,
        val isPlaying: Boolean,
        val positionMs: Long,
        val durationMs: Long,
        val artworkBytes: ByteArray?
    )

    companion object {
        const val CHANNEL_ID = "dagiplayer_playback_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_PLAY = "com.dagi.dagiplayer.ACTION_PLAY"
        const val ACTION_PAUSE = "com.dagi.dagiplayer.ACTION_PAUSE"
        const val ACTION_PLAY_PAUSE = "com.dagi.dagiplayer.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.dagi.dagiplayer.ACTION_NEXT"
        const val ACTION_PREV = "com.dagi.dagiplayer.ACTION_PREV"
        const val ACTION_STOP = "com.dagi.dagiplayer.ACTION_STOP"
        const val ACTION_UPDATE = "com.dagi.dagiplayer.ACTION_UPDATE"

        var listener: MediaActionListener? = null
        private var instance: MediaNotificationService? = null
        private var latestMediaData: MediaData? = null
        var mediaSession: MediaSessionCompat? = null
            private set

        fun update(context: Context, data: MediaData) {
            latestMediaData = data
            val appContext = context.applicationContext ?: context
            val currentInstance = instance
            if (currentInstance != null) {
                currentInstance.displayNotification(data)
                // Ensure service transitions to started state (not just bound) so it survives Activity destruction / screen lock
                if (data.isPlaying && !currentInstance.isStartedService) {
                    try {
                        val intent = Intent(appContext, MediaNotificationService::class.java).apply {
                            action = ACTION_UPDATE
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(appContext, intent)
                        } else {
                            appContext.startService(intent)
                        }
                        currentInstance.isStartedService = true
                    } catch (_: Throwable) {}
                }
            } else {
                if (!data.isPlaying) {
                    return
                }
                val intent = Intent(appContext, MediaNotificationService::class.java).apply {
                    action = ACTION_UPDATE
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(appContext, intent)
                    } else {
                        appContext.startService(intent)
                    }
                } catch (e: Throwable) {
                    try {
                        appContext.startService(intent)
                    } catch (_: Throwable) {}
                }
            }
        }

        fun stop(context: Context) {
            latestMediaData = null
            try {
                instance?.releaseWakeLock()
                instance?.isForegroundServiceRunning = false
                instance?.isStartedService = false
                instance?.cachedArtworkBitmap = null
                instance?.cachedArtworkBytesHash = 0
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    instance?.stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    instance?.stopForeground(true)
                }
                instance?.stopSelf()
            } catch (_: Throwable) {}
            try {
                mediaSession?.isActive = false
                mediaSession?.release()
                mediaSession = null
            } catch (_: Throwable) {}
            try {
                val appContext = context.applicationContext ?: context
                val intent = Intent(appContext, MediaNotificationService::class.java)
                appContext.stopService(intent)
            } catch (_: Throwable) {}
        }
    }

    var isStartedService = false
    private var isForegroundServiceRunning = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var cachedArtworkBitmap: Bitmap? = null
    private var cachedArtworkBytesHash: Int = 0

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_PLAY -> listener?.onPlay()
                ACTION_PAUSE -> listener?.onPause()
                ACTION_PLAY_PAUSE -> listener?.onPlayPause()
                ACTION_NEXT -> listener?.onNext()
                ACTION_PREV -> listener?.onPrevious()
                ACTION_STOP -> {
                    listener?.onStop()
                    stop(this@MediaNotificationService)
                }
            }
        }
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DagiPlayer:PlaybackWakeLock")?.apply {
                    setReferenceCounted(false)
                }
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(3600000) // 1 hour max safeguard timeout
            }
        } catch (_: Throwable) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Throwable) {}
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        initMediaSession()

        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY)
            addAction(ACTION_PAUSE)
            addAction(ACTION_PLAY_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_PREV)
            addAction(ACTION_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(actionReceiver, filter)
        }

        // Display current media data immediately using full MediaStyle notification
        latestMediaData?.let { data ->
            if (data.isPlaying) {
                acquireWakeLock()
            }
            displayNotification(data)
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        isForegroundServiceRunning = false
        isStartedService = false
        cachedArtworkBitmap = null
        cachedArtworkBytesHash = 0
        try {
            unregisterReceiver(actionReceiver)
        } catch (_: Throwable) {}
        instance = null
        super.onDestroy()
    }

    inner class LocalBinder : Binder() {
        fun getService(): MediaNotificationService = this@MediaNotificationService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isStartedService = true
        if (intent != null) {
            when (intent.action) {
                ACTION_PLAY -> listener?.onPlay()
                ACTION_PAUSE -> listener?.onPause()
                ACTION_PLAY_PAUSE -> listener?.onPlayPause()
                ACTION_NEXT -> listener?.onNext()
                ACTION_PREV -> listener?.onPrevious()
                ACTION_STOP -> {
                    listener?.onStop()
                    stop(this@MediaNotificationService)
                    return START_NOT_STICKY
                }
                else -> {
                    latestMediaData?.let { displayNotification(it) }
                }
            }
        } else {
            // Recreated by system under START_STICKY
            latestMediaData?.let { displayNotification(it) }
        }
        return START_STICKY
    }

    private fun initMediaSession() {
        if (mediaSession != null) return
        mediaSession = MediaSessionCompat(applicationContext, "DagiPlayerMediaSession").apply {
            isActive = true
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    listener?.onPlay()
                }

                override fun onPause() {
                    listener?.onPause()
                }

                override fun onSkipToNext() {
                    listener?.onNext()
                }

                override fun onSkipToPrevious() {
                    listener?.onPrevious()
                }

                override fun onSeekTo(pos: Long) {
                    listener?.onSeek(pos)
                }

                override fun onStop() {
                    listener?.onStop()
                    stop(this@MediaNotificationService)
                }
            })
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "DagiPlayer Music Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live playback controls in the Quick Settings panel"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(data: MediaData): Notification {
        val session = mediaSession

        // 1. Update PlaybackState for Android 11+ Quick Settings Scrubber & Buttons
        val state = if (data.isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val playbackSpeed = if (data.isPlaying) 1.0f else 0.0f
        val actions = PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_STOP

        val playbackState = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, data.positionMs, playbackSpeed)
            .build()
        session?.setPlaybackState(playbackState)

        // 2. Decode Artwork Bitmap with caching so we don't re-decode on every tick
        if (data.artworkBytes != null && data.artworkBytes.isNotEmpty()) {
            val bytesHash = data.artworkBytes.contentHashCode()
            if (cachedArtworkBitmap == null || cachedArtworkBytesHash != bytesHash) {
                try {
                    cachedArtworkBitmap = BitmapFactory.decodeByteArray(data.artworkBytes, 0, data.artworkBytes.size)
                    cachedArtworkBytesHash = bytesHash
                } catch (_: Throwable) {}
            }
        }
        val artworkBitmap = cachedArtworkBitmap

        // 3. Update Media Metadata
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, data.title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, data.artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, data.album ?: "DagiPlayer")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, data.durationMs)

        if (artworkBitmap != null) {
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artworkBitmap)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, artworkBitmap)
        }
        session?.setMetadata(metadataBuilder.build())

        // 4. Create Broadcast PendingIntents for Action Buttons
        val prevPending = PendingIntent.getBroadcast(
            this, 1,
            Intent(ACTION_PREV).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playPauseAction = if (data.isPlaying) ACTION_PAUSE else ACTION_PLAY
        val playPausePending = PendingIntent.getBroadcast(
            this, 2,
            Intent(playPauseAction).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val nextPending = PendingIntent.getBroadcast(
            this, 3,
            Intent(ACTION_NEXT).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopPending = PendingIntent.getBroadcast(
            this, 4,
            Intent(ACTION_STOP).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Open app intent
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPending = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playPauseIcon = if (data.isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val playPauseTitle = if (data.isPlaying) "Pause" else "Play"

        val iconRes = try {
            R.drawable.ic_notification
        } catch (_: Throwable) {
            android.R.drawable.ic_media_play
        }

        // 5. Build MediaStyle Notification for Android Quick Panel
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(iconRes)
            .setContentTitle(data.title)
            .setContentText(data.artist)
            .setSubText(data.album)
            .setContentIntent(openAppPending)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(data.isPlaying)
            .setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPending)
            .addAction(playPauseIcon, playPauseTitle, playPausePending)
            .addAction(android.R.drawable.ic_media_next, "Next", nextPending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPending)

        if (session != null) {
            notificationBuilder.setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
        }

        if (artworkBitmap != null) {
            notificationBuilder.setLargeIcon(artworkBitmap)
        }

        return notificationBuilder.build()
    }

    private fun displayNotification(data: MediaData) {
        val notification = buildNotification(data)
        val manager = getSystemService(NotificationManager::class.java)

        if (data.isPlaying) {
            acquireWakeLock()
            if (!isForegroundServiceRunning) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        ServiceCompat.startForeground(
                            this,
                            NOTIFICATION_ID,
                            notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                    isForegroundServiceRunning = true
                } catch (e: Throwable) {
                    android.util.Log.w("MediaNotification", "startForeground failed: ${e.message}")
                    try {
                        manager?.notify(NOTIFICATION_ID, notification)
                    } catch (_: Throwable) {}
                }
            } else {
                // Update in-place without re-calling startForeground()
                try {
                    manager?.notify(NOTIFICATION_ID, notification)
                } catch (_: Throwable) {}
            }
        } else {
            releaseWakeLock()
            // When paused, keep the notification in-place in Quick Settings
            try {
                manager?.notify(NOTIFICATION_ID, notification)
            } catch (_: Throwable) {}
        }
    }
}
