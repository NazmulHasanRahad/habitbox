package com.example.habitbox

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private var pendingToggleHabitId = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "habitbox/widgets",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncData" -> {
                        val habitsJson = call.arguments as? String
                        if (habitsJson == null) {
                            result.error(
                                "invalid_data",
                                "Habit widget data was missing.",
                                null,
                            )
                        } else {
                            HabitWidgetProvider.syncData(this, habitsJson)
                            result.success(null)
                        }
                    }
                    "requestPin" -> result.success(
                        HabitWidgetProvider.requestPin(this),
                    )
                    else -> result.notImplemented()
                }
            }
        }
        pendingToggleHabitId.takeIf { it > 0 }?.let { deliverToggle(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleToggleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleToggleIntent(intent)
    }

    private fun handleToggleIntent(intent: Intent?) {
        val habitId = intent?.getIntExtra(TOGGLE_HABIT_EXTRA, -1) ?: -1
        // Consumed once: a recreate (rotation, theme change) must not toggle
        // the habit a second time.
        intent?.removeExtra(TOGGLE_HABIT_EXTRA)
        if (habitId <= 0) return
        pendingToggleHabitId = habitId
        widgetChannel?.let { deliverToggle(habitId) }
    }

    /// Hands the widget's mark tap to Dart. The Dart handler registers in
    /// main() before runApp, but the engine can still be starting when the
    /// intent lands, so a not-implemented answer is retried briefly instead of
    /// dropping the tap — a successful call stops the loop so the habit is
    /// never toggled twice.
    private fun deliverToggle(habitId: Int) {
        var attempt = 0
        val runnable = object : Runnable {
            override fun run() {
                val channel = widgetChannel
                if (channel == null) {
                    schedule()
                    return
                }
                attempt++
                channel.invokeMethod(
                    "toggleToday",
                    habitId,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            pendingToggleHabitId = -1
                        }
                        override fun error(
                            errorCode: String,
                            errorMessage: String?,
                            errorDetails: Any?,
                        ) {
                            schedule()
                        }
                        override fun notImplemented() = schedule()
                    },
                )
            }

            private fun schedule() {
                if (attempt < MAX_TOGGLE_ATTEMPTS) {
                    window.decorView.postDelayed(this, RETRY_DELAY_MS)
                }
            }
        }
        runnable.run()
    }

    companion object {
        const val TOGGLE_HABIT_EXTRA = "habitbox_toggle_habit"
        private const val MAX_TOGGLE_ATTEMPTS = 8
        private const val RETRY_DELAY_MS = 400L
    }
}
