package com.example.habitbox

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class HabitWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        refresh(context, appWidgetIds)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val editor = preferences.edit()
        appWidgetIds.forEach { editor.remove(habitKey(it)) }
        editor.apply()
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        refresh(context, intArrayOf(appWidgetId))
    }

    companion object {
        private const val PREFERENCES = "habitbox_home_widgets"
        private const val HABITS_JSON = "habits_json"
        private const val MAX_HEATMAP_WEEKS = 26
        private const val HEATMAP_DAYS = MAX_HEATMAP_WEEKS * 7

        // Header above the graph: padding, title, description and the mark
        // button, in dp.
        private const val WIDGET_HEADER_DP = 78
        private const val MILLIS_PER_DAY = 86_400_000L

        private fun habitKey(appWidgetId: Int) = "habit_widget_habit_$appWidgetId"

        fun requestPin(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            val manager = AppWidgetManager.getInstance(context)
            if (!manager.isRequestPinAppWidgetSupported) return false
            val requestId = System.currentTimeMillis().toInt()
            val callbackIntent =
                Intent(context, HabitWidgetConfigureActivity::class.java).apply {
                    action = "${context.packageName}.PIN_WIDGET.$requestId"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            val callback = PendingIntent.getActivity(
                context,
                requestId,
                callbackIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            return manager.requestPinAppWidget(
                ComponentName(context, HabitWidgetProvider::class.java),
                null,
                callback,
            )
        }

        fun syncData(context: Context, habitsJson: String) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putString(HABITS_JSON, habitsJson)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, HabitWidgetProvider::class.java),
            )
            refresh(context, ids)
        }

        fun refresh(context: Context, appWidgetIds: IntArray) {
            val manager = AppWidgetManager.getInstance(context)
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            val habits = JSONArray(preferences.getString(HABITS_JSON, "[]"))

            appWidgetIds.forEach { appWidgetId ->
                val selectedHabitId = preferences.getInt(habitKey(appWidgetId), -1)
                val habit = (0 until habits.length())
                    .asSequence()
                    .map { habits.getJSONObject(it) }
                    .firstOrNull { it.optInt("id", -1) == selectedHabitId }
                manager.updateAppWidget(
                    appWidgetId,
                    buildViews(
                        context,
                        appWidgetId,
                        habit,
                        manager.getAppWidgetOptions(appWidgetId),
                    ),
                )
            }
        }

        private fun buildViews(
            context: Context,
            appWidgetId: Int,
            habit: org.json.JSONObject?,
            options: android.os.Bundle,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.habit_widget)
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openApp = PendingIntent.getActivity(
                context,
                appWidgetId,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)

            if (habit == null) {
                views.setTextViewText(R.id.widget_title, "Choose a habit")
                views.setTextViewText(R.id.widget_icon, "?")
                views.setTextColor(R.id.widget_icon, Color.LTGRAY)
                views.setTextViewText(R.id.widget_mark_glyph, "+")
                views.setTextColor(R.id.widget_mark_glyph, Color.LTGRAY)
                views.setInt(
                    R.id.widget_mark_bg,
                    "setColorFilter",
                    Color.rgb(46, 54, 50),
                )
                views.setOnClickPendingIntent(R.id.widget_mark_button, openApp)
                views.setTextViewText(
                    R.id.widget_summary,
                    "Add HabitBox again and select a habit",
                )
                views.setViewVisibility(R.id.widget_description, View.GONE)
                views.removeAllViews(R.id.widget_graph_rows)
                return views
            }

            val color = habit.optLong("color", 0xFF7C4DFF).toInt()
            val completedByDate = habit.optJSONObject("completedByDate") ?: JSONObject()
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val date = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                val daysSinceMonday = (get(Calendar.DAY_OF_WEEK) + 5) % 7
                add(Calendar.DATE, -daysSinceMonday - (MAX_HEATMAP_WEEKS - 1) * 7)
            }
            val today = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val days = List(HEATMAP_DAYS) { index ->
                val day = (date.clone() as Calendar).apply { add(Calendar.DATE, index) }
                completedByDate.optBoolean(dateFormat.format(day.time)) &&
                    !day.after(today)
            }
            val visibleWeeks = visibleHeatmapWeeks(context, options)
            val visibleDays = days.takeLast(visibleWeeks * 7)

            // `days` ends on the Sunday of the current week, so its last slot
            // is a future day — today has to be located by date instead.
            val todayIndex =
                ((today.timeInMillis - date.timeInMillis) / MILLIS_PER_DAY)
                    .toInt()
                    .coerceIn(0, days.lastIndex)
            val todayDone = days[todayIndex]
            // Index of today inside the visible slice used by the week loop.
            val todayVisibleIndex = todayIndex - (days.size - visibleDays.size)

            // No stats line: the header is icon, title, description and the
            // mark button only.
            views.setViewVisibility(R.id.widget_summary, View.GONE)
            views.removeAllViews(R.id.widget_graph_rows)

            // Cells are a dark wash of the accent on the widget background.
            val mutedColor = blendColors(Color.rgb(16, 22, 19), color, 0.16f)

            val habitName = habit.optString("name", "Habit")
            views.setTextViewText(R.id.widget_title, habitName)

            // The stored icon is a Flutter MaterialIcons code point; the same
            // font is bundled in res/font, so the glyph draws natively here.
            val iconCodePoint = habit.optInt("iconCodePoint", 0)
            views.setTextViewText(
                R.id.widget_icon,
                if (iconCodePoint > 0) {
                    String(Character.toChars(iconCodePoint))
                } else {
                    "?"
                },
            )
            views.setTextColor(
                R.id.widget_icon,
                blendColors(color, Color.WHITE, 0.3f),
            )

            val description = habit.optString("description", "").trim()
            if (description.isEmpty()) {
                views.setViewVisibility(R.id.widget_description, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_description, description)
                views.setViewVisibility(R.id.widget_description, View.VISIBLE)
            }
            // --- Mark / unmark button -------------------------------------
            // Mirrors the card button: yes/no is a rounded square that fills
            // with the accent once done; count/measure is a circle that fills
            // at the goal. Tapping a yes/no habit toggles today through the
            // app; count/measure opens the app to log a value.
            val isYesNo = habit.optString("type", "yes_no") == "yes_no"
            val fraction = habit.optDouble("todayFraction", 0.0)
            val complete = (isYesNo && todayDone) || (!isYesNo && fraction >= 1.0)
            views.setInt(
                R.id.widget_mark_bg,
                "setImageResource",
                if (isYesNo) {
                    R.drawable.habit_widget_mark_bg
                } else {
                    R.drawable.habit_widget_mark_circle
                },
            )
            views.setInt(
                R.id.widget_mark_bg,
                "setColorFilter",
                // Done wears the accent; open stays a dark wash of it.
                if (complete) color else mutedColor,
            )
            views.setTextViewText(
                R.id.widget_mark_glyph,
                when {
                    isYesNo -> "✓"
                    complete -> "✓"
                    else -> "+"
                },
            )
            views.setTextColor(
                R.id.widget_mark_glyph,
                if (complete) Color.WHITE else Color.argb(179, 255, 255, 255),
            )
            if (isYesNo) {
                val habitId = habit.optInt("id", -1)
                val toggleIntent = Intent(context, MainActivity::class.java).apply {
                    putExtra(MainActivity.TOGGLE_HABIT_EXTRA, habitId)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                views.setOnClickPendingIntent(
                    R.id.widget_mark_button,
                    PendingIntent.getActivity(
                        context,
                        appWidgetId + 1000,
                        toggleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or
                            PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            } else {
                views.setOnClickPendingIntent(R.id.widget_mark_button, openApp)
            }
            repeat(visibleWeeks) { weekIndex ->
                val week = RemoteViews(context.packageName, R.layout.habit_widget_week)
                repeat(7) { dayIndex ->
                    val globalIndex = weekIndex * 7 + dayIndex
                    val dotId = context.resources.getIdentifier(
                        "widget_day_$dayIndex",
                        "id",
                        context.packageName,
                    )
                    val isComplete = visibleDays[globalIndex]
                    // Today wears an outline instead of a fill, so it reads as
                    // "now" even when it is not done yet.
                    week.setInt(
                        dotId,
                        "setImageResource",
                        if (globalIndex == todayVisibleIndex) {
                            R.drawable.habit_widget_cell_today
                        } else {
                            R.drawable.habit_widget_heatmap_cell
                        },
                    )
                    week.setInt(
                        dotId,
                        "setColorFilter",
                        if (isComplete) color else mutedColor,
                    )
                }
                views.addView(R.id.widget_graph_rows, week)
            }
            return views
        }

        private fun visibleHeatmapWeeks(
            context: Context,
            options: android.os.Bundle,
        ): Int {
            val isLandscape =
                context.resources.configuration.orientation ==
                    Configuration.ORIENTATION_LANDSCAPE
            val widthOption = if (isLandscape) {
                AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
            } else {
                AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
            }
            val heightOption = if (isLandscape) {
                AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
            } else {
                AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
            }
            val widgetWidth = options.getInt(widthOption, 180).coerceAtLeast(180)
            val widgetHeight = options.getInt(heightOption, 140).coerceAtLeast(140)
            val graphWidth = (widgetWidth - 24).coerceAtLeast(8)
            val graphHeight = (widgetHeight - WIDGET_HEADER_DP).coerceAtLeast(42)

            // Cells stay square: each stretched row is a seventh of the graph
            // minus its 2dp gap, and a week column is that plus its 2dp gap.
            val cellSide = (graphHeight / 7f - 2f).coerceAtLeast(4f)
            return (graphWidth / (cellSide + 2f))
                .toInt()
                .coerceIn(1, MAX_HEATMAP_WEEKS)
        }

        private fun blendColors(background: Int, accent: Int, amount: Float): Int {
            val inverse = 1f - amount
            return Color.rgb(
                (Color.red(background) * inverse + Color.red(accent) * amount).toInt(),
                (Color.green(background) * inverse + Color.green(accent) * amount).toInt(),
                (Color.blue(background) * inverse + Color.blue(accent) * amount).toInt(),
            )
        }
    }
}
