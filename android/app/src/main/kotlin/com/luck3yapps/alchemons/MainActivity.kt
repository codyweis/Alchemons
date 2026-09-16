package com.luck3yapps.alchemons

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets a Dart transition that hides an orientation change (the glyph
        // portal counter-rotates itself) turn off the system's own rotation
        // animation, which would otherwise spin the screen mid-effect.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alchemons/rotation")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSeamless" -> {
                        val on = call.arguments as? Boolean ?: false
                        val attrs = window.attributes
                        attrs.rotationAnimation = when {
                            !on -> WindowManager.LayoutParams.ROTATION_ANIMATION_ROTATE
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ->
                                WindowManager.LayoutParams.ROTATION_ANIMATION_SEAMLESS
                            else -> WindowManager.LayoutParams.ROTATION_ANIMATION_JUMPCUT
                        }
                        window.attributes = attrs
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
