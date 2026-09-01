package com.hermes.mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object HermesPushBridge {
  private const val channelName = "hermes.push"
  private const val preferencesName = "hermes_push"
  private const val tokenKey = "fcm_token"
  private var channel: MethodChannel? = null
  private val pending = mutableListOf<Pair<String, Map<String, Any?>>>()

  fun configure(context: Context, engine: FlutterEngine) {
    channel = MethodChannel(engine.dartExecutor.binaryMessenger, channelName).also { methodChannel ->
      methodChannel.setMethodCallHandler { call, result ->
        when (call.method) {
          "getToken" -> getToken(context, result)
          "deleteToken" -> {
            if (!ensureFirebase(context)) {
              result.success(null)
            } else {
              FirebaseMessaging.getInstance().deleteToken()
                .addOnCompleteListener {
                  context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                    .edit().remove(tokenKey).apply()
                  result.success(null)
                }
            }
          }
          else -> result.notImplemented()
        }
      }
    }
    val queued = synchronized(pending) { pending.toList().also { pending.clear() } }
    queued.forEach { (method, payload) -> channel?.invokeMethod(method, payload) }
    handleIntent((context as? android.app.Activity)?.intent)
  }

  private fun getToken(context: Context, result: MethodChannel.Result) {
    if (!ensureFirebase(context)) {
      result.success(null)
      return
    }
    FirebaseMessaging.getInstance().token
      .addOnSuccessListener { token ->
        storeToken(context, token)
        result.success(mapOf("platform" to "android", "token" to token))
      }
      .addOnFailureListener { error -> result.error("push_token", error.message, null) }
  }

  fun ensureFirebase(context: Context): Boolean {
    if (FirebaseApp.getApps(context).isNotEmpty()) return true
    val metadata = try {
      context.packageManager.getApplicationInfo(
        context.packageName,
        PackageManager.GET_META_DATA,
      ).metaData
    } catch (_: Exception) {
      return false
    }
    val appId = metadata?.getString("hermes.push.fcm_app_id").orEmpty()
    val apiKey = metadata?.getString("hermes.push.fcm_api_key").orEmpty()
    val projectId = metadata?.getString("hermes.push.fcm_project_id").orEmpty()
    val senderId = metadata?.getString("hermes.push.fcm_sender_id").orEmpty()
    if (appId.isBlank() || apiKey.isBlank() || projectId.isBlank() || senderId.isBlank()) {
      return false
    }
    val options = FirebaseOptions.Builder()
      .setApplicationId(appId)
      .setApiKey(apiKey)
      .setProjectId(projectId)
      .setGcmSenderId(senderId)
      .build()
    return FirebaseApp.initializeApp(context, options) != null
  }

  fun onNewToken(context: Context, token: String) {
    storeToken(context, token)
    emit("token", mapOf("platform" to "android", "token" to token))
  }

  private fun storeToken(context: Context, token: String) {
    context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
      .edit().putString(tokenKey, token).apply()
  }

  fun onMessage(message: RemoteMessage) {
    val payload = message.data.mapValues { it.value }.toMutableMap<String, Any?>()
    message.notification?.title?.let { payload["title"] = it }
    message.notification?.body?.let { payload["body"] = it }
    message.messageId?.let { payload.putIfAbsent("notification_id", it) }
    emit("message", payload)
  }

  fun handleIntent(intent: Intent?) {
    val extras = intent?.extras ?: return
    if (!extras.containsKey("notification_id") &&
      !extras.containsKey("event_type") &&
      !extras.containsKey("session_id")) return
    val payload = mutableMapOf<String, Any?>()
    extras.keySet().forEach { key ->
      val value = extras.get(key)
      if (value is String || value is Boolean || value is Number) payload[key] = value
    }
    emit("tap", payload)
    intent.replaceExtras(android.os.Bundle())
  }

  private fun emit(method: String, payload: Map<String, Any?>) {
    val active = channel
    if (active == null) {
      synchronized(pending) { pending.add(method to payload) }
    } else {
      active.invokeMethod(method, payload)
    }
  }
}

class HermesFirebaseMessagingService : FirebaseMessagingService() {
  override fun onCreate() {
    super.onCreate()
    HermesPushBridge.ensureFirebase(this)
  }

  override fun onNewToken(token: String) {
    super.onNewToken(token)
    HermesPushBridge.onNewToken(this, token)
  }

  override fun onMessageReceived(message: RemoteMessage) {
    super.onMessageReceived(message)
    HermesPushBridge.onMessage(message)
  }
}
