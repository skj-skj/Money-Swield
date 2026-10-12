package com.skj.expense.tracker.my_expense_tracker_app

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `expense_tracker/on_device_ai` in the foss build: no on-device AI and no
 * Google code, so the SMS are read by the regex only. Same name and constructor
 * as play's, so `MainActivity` is one file for both flavors.
 */
class OnDeviceAi(messenger: BinaryMessenger, @Suppress("UNUSED_PARAMETER") context: Context) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "expense_tracker/on_device_ai")

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success("unavailable")
            "download", "prompt" -> result.error("unavailable", "no on-device AI in foss", null)
            else -> result.notImplemented()
        }
    }
}
