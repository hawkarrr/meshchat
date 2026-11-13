package com.example.offline_mesh_chat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app's process alive while the screen is off, so the Bluetooth mesh
 * keeps relaying and receiving. It does nothing itself: all the Bluetooth work
 * runs in the Flutter engine of the app, which MainActivity keeps alive for as
 * long as the process lives (also after the activity is closed or swiped away).
 * What this adds is the ongoing notification that Android requires of a
 * foreground service, and the promise to the system that the app is connected to
 * nearby devices.
 *
 * It is started only when the person turns "Keep the mesh running in the
 * background" on, from the Dart side while the app is on screen (Android 12 and
 * newer do not allow starting one from the background), and stopped when they
 * turn it off or Bluetooth is stopped. If the system refuses to let it become a
 * foreground service (a missing permission, a restriction), it ends itself
 * instead of crashing the app; [running] then stays false, and the app, which
 * asks for it after every start, turns its switch off.
 *
 * Nothing here is verified on a real phone yet; see docs/real-device-test-plan.md.
 */
class KeepAliveService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            // Words from the app (in the person's language), kept for the next
            // time the notification is rebuilt.
            intent?.getStringExtra(EXTRA_TITLE)?.let { title = it }
            intent?.getStringExtra(EXTRA_TEXT)?.let { text = it }
            intent?.getStringExtra(EXTRA_CHANNEL_NAME)?.let { channelName = it }
            intent?.getStringExtra(EXTRA_CHANNEL_DESCRIPTION)?.let { channelDescription = it }
            createChannel()
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            running = true
        } catch (e: Exception) {
            // Android refused (for example the Bluetooth permission that the
            // connected-device type depends on is not granted). Do not crash:
            // end the service, and the app's switch reports that it is off.
            running = false
            stopSelf()
        }
        // If the system ends the process for memory, do not come back on our own:
        // the app starts the service again the next time it is opened.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Creating a channel that exists updates its name and description, so a
        // change of the app's language reaches the system's notification settings.
        val channel = NotificationChannel(
            CHANNEL_ID,
            channelName,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = channelDescription
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_damataqe)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
    }

    // English until the app sends its own words (it does, in the person's language).
    private var title: String = "دەمەتەقێ is keeping the mesh running"
    private var text: String = "Relaying and receiving messages over Bluetooth. Tap to open."
    private var channelName: String = "Mesh running in the background"
    private var channelDescription: String =
        "Shown while دەمەتەقێ keeps the Bluetooth mesh running with the screen off."

    companion object {
        private const val CHANNEL_ID = "mesh_keep_alive"
        private const val NOTIFICATION_ID = 4107
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_CHANNEL_NAME = "channelName"
        private const val EXTRA_CHANNEL_DESCRIPTION = "channelDescription"

        @Volatile
        var running: Boolean = false
            private set

        fun start(
            context: Context,
            title: String? = null,
            text: String? = null,
            channelName: String? = null,
            channelDescription: String? = null
        ) {
            // Until this request has made the service a foreground service, it does
            // not count as running: the app asks [running] to confirm that it did.
            running = false
            val intent = Intent(context, KeepAliveService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_CHANNEL_NAME, channelName)
                .putExtra(EXTRA_CHANNEL_DESCRIPTION, channelDescription)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * Stopping a service is allowed from the background, and the system
         * removes the foreground notification together with the service.
         */
        fun stop(context: Context) {
            context.stopService(Intent(context, KeepAliveService::class.java))
        }
    }
}
