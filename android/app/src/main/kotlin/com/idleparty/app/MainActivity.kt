package com.idleparty.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenChannel = "idle_party/screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepScreenOn" -> {
                        val on = call.argument<Boolean>("on") == true
                        runOnUiThread {
                            if (on) {
                                window.addFlags(
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                                )
                            } else {
                                window.clearFlags(
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                                )
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
