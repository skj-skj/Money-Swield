package com.skj.expense.tracker.my_expense_tracker_app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs the app on one Flutter engine per process, kept in FlutterEngineCache.
 *
 * By default every new activity gets a new engine, and so a second `main()`.
 * When Android destroys and recreates the activity while the process lives
 * on (back during the migration screen, or a relaunch), the old engine's
 * native SQLite connection stays open in the sqflite plugin, holding the lock
 * of a half-done migration, and the new engine's migrations fail with
 * "database is locked". With one engine, a recreated activity attaches to
 * the same Dart isolate: migrations keep running and run only once.
 *
 * Side effect, accepted: leaving with back and reopening returns to where
 * the app was instead of restarting it.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { return it }
        // Plugins are registered by the engine itself; FlutterActivity skips
        // configureFlutterEngine's registration for engines it doesn't own.
        val appContext = context.applicationContext
        val engine = FlutterEngine(appContext)
        // Registered before Dart starts, so main() can ask for it at once.
        registerDynamicColor(engine, appContext)
        documents = DocumentsChannel(engine.dartExecutor.binaryMessenger, appContext)
        photos = PhotosChannel(engine.dartExecutor.binaryMessenger, appContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        cache.put(ENGINE_ID, engine)
        return engine
    }

    // A provided engine is not destroyed with the activity by default; said
    // here explicitly because the whole point is that it outlives it.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    // The documents and photos channels live with the engine; each
    // activity lends itself to them for their dialogs (PendingActivityCall).
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState) // Calls provideFlutterEngine.
        documents?.dialog?.attach(this)
        photos?.dialog?.attach(this)
    }

    override fun onDestroy() {
        documents?.dialog?.detach(this)
        photos?.dialog?.detach(this)
        super.onDestroy()
    }

    // FlutterActivity isn't a ComponentActivity, so no Activity Result API.
    // super first, so Flutter's own plugins still get their results.
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (documents?.dialog?.onActivityResult(requestCode, resultCode, data) == true) return
        photos?.dialog?.onActivityResult(requestCode, resultCode, data)
    }

    /**
     * Answers `accentColor` with the wallpaper's accent color (Android 12+)
     * as ARGB, or null on older Android. The app builds its Material color
     * scheme from it with the same tonal-palette algorithm Android uses.
     *
     * A few lines here instead of the dynamic_color package: that package
     * returns package:flutter/material color schemes, and this app uses
     * material_ui's own ColorScheme type.
     */
    private fun registerDynamicColor(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, DYNAMIC_COLOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "accentColor" -> result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            context.getColor(android.R.color.system_accent1_500)
                        } else {
                            null
                        },
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val ENGINE_ID = "main"
        const val DYNAMIC_COLOR_CHANNEL = "expense_tracker/dynamic_color"

        /** Created with the cached engine, so they live as long as it. */
        var documents: DocumentsChannel? = null
        var photos: PhotosChannel? = null
    }
}
