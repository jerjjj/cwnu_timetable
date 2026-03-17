package com.example.cwnu_demo

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TimetableWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TimetableWidgetFactory(applicationContext)
    }
}

class TimetableWidgetFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var courses: List<WidgetCourseInfo> = emptyList()

    override fun onCreate() {
        courses = TimetableWidgetDataSource.loadTodayCourses(context)
        markWidgetNeedsSync()
    }

    override fun onDataSetChanged() {
        courses = TimetableWidgetDataSource.loadTodayCourses(context)
        markWidgetNeedsSync()
    }

    override fun onDestroy() {
        courses = emptyList()
    }

    private fun markWidgetNeedsSync() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.timetable.widget_sync_requested", true).apply()
    }

    override fun getCount(): Int = courses.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= courses.size) {
            return RemoteViews(context.packageName, R.layout.widget_course_empty)
        }

        val course = courses[position]
        val views = RemoteViews(context.packageName, R.layout.widget_course_item)
        views.setInt(
            R.id.courseItemRoot,
            "setBackgroundColor",
            if (course.isCurrent) 0x1FFFD54F else 0x00000000,
        )
        views.setInt(
            R.id.courseColorBar,
            "setBackgroundColor",
            TimetableWidgetDataSource.colorFor(course.courseName),
        )
        views.setTextViewText(R.id.tvCourseTitle, course.courseName)
        views.setTextViewText(
            R.id.tvCourseSubtitle,
            "${course.placeName}  ${course.teacher}".trim(),
        )
        views.setTextViewText(
            R.id.tvTimeRange,
            TimetableWidgetDataSource.periodRangeText(course.startPeriod, course.endPeriod),
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
