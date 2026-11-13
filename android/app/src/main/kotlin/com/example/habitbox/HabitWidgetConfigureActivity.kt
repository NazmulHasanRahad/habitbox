package com.example.habitbox

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray

class HabitWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        val resultIntent = Intent().putExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            appWidgetId,
        )
        setResult(RESULT_CANCELED, resultIntent)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(18), dp(20), dp(18))
            setBackgroundColor(Color.rgb(16, 22, 19))
        }
        val heading = TextView(this).apply {
            text = "Choose a habit"
            textSize = 22f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, dp(5))
        }
        val description = TextView(this).apply {
            text = "This widget will show the habit you select."
            textSize = 14f
            setTextColor(Color.rgb(190, 201, 194))
        }
        root.addView(heading)
        root.addView(description)

        val preferences = getSharedPreferences(
            "habitbox_home_widgets",
            MODE_PRIVATE,
        )
        val habits = JSONArray(preferences.getString("habits_json", "[]"))
        if (habits.length() == 0) {
            root.addView(
                TextView(this).apply {
                    text = "Open HabitBox and create a habit first."
                    textSize = 16f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                },
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    0,
                    1f,
                ),
            )
            root.addView(
                Button(this).apply {
                    text = "Close"
                    setOnClickListener { finish() }
                },
            )
        } else {
            val habitNames = (0 until habits.length()).map { index ->
                habits.getJSONObject(index).optString("name", "Habit")
            }
            val list = ListView(this)
            list.divider = ColorDrawable(Color.rgb(58, 66, 62))
            list.dividerHeight = dp(1)
            list.adapter = object : ArrayAdapter<String>(
                this,
                android.R.layout.simple_list_item_1,
                habitNames,
            ) {
                override fun getView(
                    position: Int,
                    convertView: View?,
                    parent: ViewGroup,
                ): View {
                    val row = super.getView(position, convertView, parent) as TextView
                    row.setTextColor(Color.WHITE)
                    row.textSize = 16f
                    row.setPadding(dp(16), dp(13), dp(16), dp(13))
                    row.setBackgroundColor(Color.rgb(24, 32, 28))
                    return row
                }
            }
            list.setOnItemClickListener { _, _, position, _ ->
                val selectedHabitId = habits.getJSONObject(position).getInt("id")
                preferences.edit()
                    .putInt("habit_widget_habit_$appWidgetId", selectedHabitId)
                    .apply()
                HabitWidgetProvider.refresh(this, intArrayOf(appWidgetId))
                setResult(RESULT_OK, resultIntent)
                finish()
            }
            root.addView(
                list,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    0,
                    1f,
                ).apply {
                    topMargin = dp(12)
                },
            )
        }

        setContentView(root)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
