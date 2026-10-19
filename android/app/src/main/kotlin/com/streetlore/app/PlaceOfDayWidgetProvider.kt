package com.streetlore.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

import androidx.annotation.Keep

@Keep
class PlaceOfDayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE || action == "streetlore.UPDATE_WIDGET") {
            val mgr = AppWidgetManager.getInstance(context)
            val cn = ComponentName(context, PlaceOfDayWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(cn)
            for (id in ids) updateWidget(context, mgr, id)
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("streetlore_widget_v1", Context.MODE_PRIVATE)
        val title = prefs.getString("streetlore_widget_v1.place_title_en", "") ?: ""
        val snippet = prefs.getString("streetlore_widget_v1.place_snippet_en", "") ?: ""
        val temp = prefs.getFloat("streetlore_widget_v1.weather_temp_c", Float.NaN)
        val condition = prefs.getString("streetlore_widget_v1.weather_condition", "") ?: ""

        val views = RemoteViews(context.packageName, R.layout.widget_place_of_day)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_snippet, snippet)
        if (!temp.isNaN()) {
            views.setTextViewText(R.id.widget_temp, "${temp.toInt()}°")
        } else {
            views.setTextViewText(R.id.widget_temp, "")
        }
        views.setTextViewText(R.id.widget_condition, condition)

        val placeId = prefs.getString("streetlore_widget_v1.place_id", null)
        val intent = if (placeId != null) {
            Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("streetlore://place/$placeId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
        } else {
            context.packageManager.getLaunchIntentForPackage(context.packageName)
        }
        val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
