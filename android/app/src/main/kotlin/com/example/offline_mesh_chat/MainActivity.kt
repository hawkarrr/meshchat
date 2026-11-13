package com.example.offline_mesh_chat

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /**
     * One Flutter engine for the whole process, kept in [FlutterEngineCache].
     *
     * All of the app's Bluetooth work runs in Dart, inside this engine. A
     * FlutterActivity destroys the engine it created itself when the activity is
     * destroyed (the app swiped away from Recents, or finished), which used to stop
     * the mesh while KeepAliveService still said "keeping the mesh running". An
     * engine provided here outlives the activity: it runs as long as the process
     * does (which the foreground service, when it is on, asks Android to allow),
     * and the next activity attaches to the same engine and finds the app as it was.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val cache = FlutterEngineCache.getInstance()
        return cache.get(ENGINE_ID)
            ?: FlutterEngine(context.applicationContext).also { cache.put(ENGINE_ID, it) }
    }

    /**
     * Back on the first screen sends the app to the background instead of
     * finishing it, as messengers do: the mesh keeps going, and coming back finds
     * the app where it was.
     */
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The engine outlives this activity, so the handler holds the application
        // context only, never the activity. A new activity sets it again.
        val app = applicationContext
        // "Keep the mesh running in the background": starts and stops the
        // foreground service in KeepAliveService.kt, and says whether the phone's
        // battery optimisation still applies to the app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEP_ALIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            // The words of the ongoing notification come from the app,
                            // in the language the person chose: Android's own
                            // translations follow the phone's language, not the app's.
                            val args = call.arguments as? Map<*, *>
                            KeepAliveService.start(
                                app,
                                title = args?.get("title") as? String,
                                text = args?.get("text") as? String,
                                channelName = args?.get("channelName") as? String,
                                channelDescription = args?.get("channelDescription") as? String
                            )
                            // Accepted only: the service reports through "isRunning"
                            // whether it really became a foreground service.
                            result.success(true)
                        } catch (e: Exception) {
                            // Android refuses a foreground service in some states
                            // (for example when the app is not on screen).
                            result.error("start_failed", e.message, null)
                        }
                    }
                    "stop" -> {
                        KeepAliveService.stop(app)
                        result.success(true)
                    }
                    "isRunning" -> result.success(KeepAliveService.running)
                    "batteryRestricted" -> {
                        try {
                            result.success(isBatteryRestricted(app))
                        } catch (e: Exception) {
                            result.error("battery_unknown", e.message, null)
                        }
                    }
                    "openBatterySettings" -> result.success(openBatterySettings(app))
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val KEEP_ALIVE_CHANNEL = "damataqe/keep_alive"
        private const val ENGINE_ID = "damataqe"

        /** Whether Android's battery optimisation still applies to this app. */
        private fun isBatteryRestricted(context: Context): Boolean {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return !power.isIgnoringBatteryOptimizations(context.packageName)
        }

        /**
         * Opens the page where the person can let the app run without battery
         * restrictions: the app's own page on Android 12 and newer (Battery >
         * Unrestricted), the list of optimised apps before that, and the other one if
         * a phone does not have the first. Neither needs a permission. Returns
         * whether a page was opened.
         */
        private fun openBatterySettings(context: Context): Boolean {
            val appPage = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context.packageName, null)
            )
            val optimisedApps = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            val order = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                listOf(appPage, optimisedApps)
            } else {
                listOf(optimisedApps, appPage)
            }
            for (intent in order) {
                try {
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    return true
                } catch (e: ActivityNotFoundException) {
                    // This phone does not have that page: try the next one.
                } catch (e: SecurityException) {
                    // Not allowed to open it: try the next one.
                }
            }
            return false
        }
    }
}
