package com.example.cwnu_demo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

open class TimetableWidgetProvider : AppWidgetProvider() {
    companion object {
        fun refreshAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val providerClasses = listOf(
                TimetableWidgetProvider::class.java,
                TimetableWidgetSmallProvider::class.java,
                TimetableWidgetLargeProvider::class.java,
            )

            providerClasses.forEach { providerClass ->
                val componentName = ComponentName(context, providerClass)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                if (widgetIds.isEmpty()) return@forEach

                val updateIntent = Intent(context, providerClass).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                }
                context.sendBroadcast(updateIntent)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = buildWidgetViews(context, widgetId)
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.lvCourses)
        }
    }

    private fun buildWidgetViews(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_timetable)
        views.setTextViewText(R.id.tvHeader, TimetableWidgetDataSource.buildHeaderText(context))

        val openAppIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)

        val serviceIntent = Intent(context, TimetableWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.lvCourses, serviceIntent)
        views.setEmptyView(R.id.lvCourses, R.id.tvEmpty)

        return views
    }
}
