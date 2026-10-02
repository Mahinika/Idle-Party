package com.idleparty.app

import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Play's edge-to-edge check. Bars stay hidden by the Flutter immersive lock.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    private val screenChannel = "idle_party/screen"
    private val ranksChannel = "idle_party/ranks"

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ranksChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadAll" -> {
                        val id = call.argument<String>("id") ?: ""
                        PlayRankBoard.loadAll(this, id, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
