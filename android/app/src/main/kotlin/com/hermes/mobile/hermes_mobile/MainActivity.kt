package com.hermes.mobile

import android.content.Intent
import android.os.SystemClock
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var pointerDownTime = 0L
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    HermesPushBridge.configure(this, flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hermes.preview/input")
      .setMethodCallHandler { call, result ->
        val webView = findWebView(window.decorView)
        if (webView == null) { result.success(false); return@setMethodCallHandler }
        when (call.method) {
          "pointer" -> {
            val x = call.argument<Number>("x")?.toFloat() ?: 0f
            val y = call.argument<Number>("y")?.toFloat() ?: 0f
            val hover = call.argument<Boolean>("hover") == true
            webView.requestFocus()
            if (hover) dispatch(webView, MotionEvent.ACTION_HOVER_MOVE, x, y, InputDevice.SOURCE_MOUSE)
            else {
              pointerDownTime = SystemClock.uptimeMillis()
              dispatch(webView, MotionEvent.ACTION_DOWN, x, y, InputDevice.SOURCE_TOUCHSCREEN)
              dispatch(webView, MotionEvent.ACTION_UP, x, y, InputDevice.SOURCE_TOUCHSCREEN)
            }
            result.success(true)
          }
          "scroll" -> {
            webView.scrollBy(call.argument<Number>("dx")?.toInt() ?: 0, call.argument<Number>("dy")?.toInt() ?: 0)
            result.success(true)
          }
          "text" -> {
            val events = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD).getEvents((call.argument<String>("text") ?: "").toCharArray())
            events?.forEach { webView.dispatchKeyEvent(it) }
            result.success(events != null)
          }
          "key" -> {
            val code = if ((call.argument<String>("key") ?: "").uppercase() == "ENTER") KeyEvent.KEYCODE_ENTER else KeyEvent.KEYCODE_UNKNOWN
            webView.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code)); webView.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
            result.success(code != KeyEvent.KEYCODE_UNKNOWN)
          }
          else -> result.notImplemented()
        }
      }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    HermesPushBridge.handleIntent(intent)
  }

  private fun dispatch(view: WebView, action: Int, x: Float, y: Float, source: Int) {
    val now = SystemClock.uptimeMillis()
    val down = if (pointerDownTime == 0L) now else pointerDownTime
    val event = MotionEvent.obtain(down, now, action, x, y, 0).apply { setSource(source) }
    if (action == MotionEvent.ACTION_HOVER_MOVE) view.dispatchGenericMotionEvent(event) else view.dispatchTouchEvent(event)
    event.recycle()
  }

  private fun findWebView(view: View): WebView? {
    if (view is WebView && view.visibility == View.VISIBLE) return view
    if (view is ViewGroup) for (i in view.childCount - 1 downTo 0) findWebView(view.getChildAt(i))?.let { return it }
    return null
  }
}
