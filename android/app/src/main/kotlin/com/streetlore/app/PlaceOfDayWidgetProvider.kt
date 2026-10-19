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
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isArabic = prefs.getString("flutter.streetlore_widget_v1.locale", "en") == "ar"
        val titleKey = if (isArabic) {
            "flutter.streetlore_widget_v1.place_title_ar"
        } else {
            "flutter.streetlore_widget_v1.place_title_en"
        }
        val snippetKey = if (isArabic) {
            "flutter.streetlore_widget_v1.place_snippet_ar"
        } else {
            "flutter.streetlore_widget_v1.place_snippet_en"
        }
        val title = prefs.getString(titleKey, "") ?: ""
        val snippet = prefs.getString(snippetKey, "") ?: ""
        val temp = prefs.getString("flutter.streetlore_widget_v1.weather_temp_c", null)
            ?.toFloatOrNull() ?: Float.NaN
        val conditionKey = prefs.getString("flutter.streetlore_widget_v1.weather_condition", "") ?: ""
        val condition = weatherCondition(conditionKey, isArabic)

        val views = RemoteViews(context.packageName, R.layout.widget_place_of_day)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_snippet, snippet)
        if (!temp.isNaN()) {
            views.setTextViewText(R.id.widget_temp, "${temp.toInt()}°")
        } else {
            views.setTextViewText(R.id.widget_temp, "")
        }
        views.setTextViewText(R.id.widget_condition, condition)

        val placeId = prefs.getString("flutter.streetlore_widget_v1.place_id", null)
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

    private fun weatherCondition(key: String, isArabic: Boolean): String {
        val labels = if (isArabic) {
            mapOf(
                "weather_clear_sky" to "سماء صافية",
                "weather_mainly_clear" to "غائم جزئياً",
                "weather_partly_cloudy" to "غائم جزئياً",
                "weather_overcast" to "غائم",
                "weather_fog" to "ضباب",
                "weather_drizzle" to "رذاذ",
                "weather_rain" to "ممطر",
                "weather_rain_possible" to "احتمال هطول أمطار",
                "weather_snow" to "ثلوج",
                "weather_showers" to "زخات مطر",
                "weather_thunderstorm" to "عاصفة رعدية",
                "weather_unknown" to "غير معروف",
            )
        } else {
            mapOf(
                "weather_clear_sky" to "Clear sky",
                "weather_mainly_clear" to "Mainly clear",
                "weather_partly_cloudy" to "Partly cloudy",
                "weather_overcast" to "Overcast",
                "weather_fog" to "Fog",
                "weather_drizzle" to "Drizzle",
                "weather_rain" to "Rain",
                "weather_rain_possible" to "Rain possible",
                "weather_snow" to "Snow",
                "weather_showers" to "Showers",
                "weather_thunderstorm" to "Thunderstorm",
                "weather_unknown" to "Unknown",
            )
        }
        return labels[key] ?: key
    }
}
