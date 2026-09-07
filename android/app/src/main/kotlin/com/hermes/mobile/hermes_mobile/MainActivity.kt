package com.hermes.mobile

import android.content.Intent
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
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
  companion object {
    // Mirrors the server-side upload cap in
    // server/hermes_mobile_server/domain_api.py's /files/upload-stream
    // endpoint, so a shared file that the server would reject isn't silently
    // buffered to disk here first.
    private const val MAX_SHARED_FILE_BYTES = 100L * 1024 * 1024
  }

  private var pointerDownTime = 0L
  private var shareChannel: MethodChannel? = null
  private var pendingShare: Map<String, Any>? = null
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    HermesPushBridge.configure(this, flutterEngine)
    shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hermes.share").also { channel ->
      channel.setMethodCallHandler { call, result ->
        if (call.method != "getInitialShare") { result.notImplemented(); return@setMethodCallHandler }
        result.success(pendingShare)
        pendingShare = null
      }
    }
    receiveShare(intent, publish = false)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hermes.clipboard")
      .setMethodCallHandler { call, result ->
        if (call.method != "readImage") { result.notImplemented(); return@setMethodCallHandler }
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        if (clip == null || clip.itemCount == 0) { result.success(null); return@setMethodCallHandler }
        val uri = clip.getItemAt(0).uri
        if (uri == null) { result.success(null); return@setMethodCallHandler }
        val mime = contentResolver.getType(uri) ?: clip.description.getMimeType(0) ?: ""
        if (!mime.startsWith("image/")) { result.success(null); return@setMethodCallHandler }
        try {
          val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
          result.success(bytes?.let { mapOf("bytes" to it, "mime" to mime, "filename" to "clipboard.${mime.substringAfter('/').replace("jpeg", "jpg")}") })
        } catch (error: Exception) {
          result.error("clipboard_image", error.message, null)
        }
      }
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
    receiveShare(intent, publish = true)
  }

  private fun receiveShare(intent: Intent?, publish: Boolean) {
    if (intent == null || (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE)) return
    val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
    val uris = mutableListOf<Uri>()
    if (intent.action == Intent.ACTION_SEND) intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let(uris::add)
    else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let(uris::addAll)
    val files = uris.mapNotNull(::copySharedFile)
    val payload = mapOf<String, Any>("text" to text, "files" to files)
    if (text.isBlank() && files.isEmpty()) return
    if (publish) shareChannel?.invokeMethod("shared", payload) else pendingShare = payload
    intent.action = null
    intent.removeExtra(Intent.EXTRA_TEXT)
    intent.removeExtra(Intent.EXTRA_STREAM)
  }

  private fun copySharedFile(uri: Uri): String? = try {
    var name = "shared-${System.currentTimeMillis()}"
    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
      if (cursor.moveToFirst()) name = cursor.getString(0) ?: name
    }
    val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
    val target = java.io.File(cacheDir, "hermes-shares/$safe")
    target.parentFile?.mkdirs()
    try {
      contentResolver.openInputStream(uri)?.use { input ->
        target.outputStream().use { output ->
          val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
          var totalBytes = 0L
          while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            totalBytes += read
            if (totalBytes > MAX_SHARED_FILE_BYTES) {
              throw java.io.IOException(
                "Shared file exceeds $MAX_SHARED_FILE_BYTES byte limit"
              )
            }
            output.write(buffer, 0, read)
          }
        }
      } ?: return null
    } catch (e: Exception) {
      // Delete whatever partial file was written (e.g. the size limit was
      // exceeded mid-copy) before surfacing the failure.
      target.delete()
      throw e
    }
    target.absolutePath
  } catch (_: Exception) { null }

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
