package com.luck3yapps.alchemons

import android.hardware.input.InputManager
import android.os.Build
import android.os.Handler
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity

class MainActivity : FlutterActivity(), GamepadsCompatibleActivity {
    // Game controllers: the gamepads plugin registers these to hear buttons
    // and sticks before Flutter's own key handling does.
    private var keyListener: ((KeyEvent) -> Boolean)? = null
    private var motionListener: ((MotionEvent) -> Boolean)? = null

    override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
        if (motionListener?.invoke(motionEvent) == true) return true
        return super.dispatchGenericMotionEvent(motionEvent)
    }

    override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
        if (keyListener?.invoke(keyEvent) == true) return true
        return super.dispatchKeyEvent(keyEvent)
    }

    override fun registerInputDeviceListener(
        listener: InputManager.InputDeviceListener,
        handler: Handler?,
    ) {
        val inputManager = getSystemService(INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(listener, null)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyListener = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionListener = handler
    }

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
