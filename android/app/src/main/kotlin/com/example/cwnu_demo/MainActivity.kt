package com.example.cwnu_demo

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onStart() {
        super.onStart()
        TimetableWidgetProvider.refreshAllWidgets(this)
    }
}
