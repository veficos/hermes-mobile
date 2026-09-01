import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pendingPushEvents: [(String, [String: Any])] = []
  private var pendingTokenResults: [FlutterResult] = []
  private var apnsToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      queuePushEvent("tap", payload: pushPayload(payload))
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "HermesPushBridge"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "hermes.push",
      binaryMessenger: registrar.messenger()
    )
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "getToken":
        if let token = self.apnsToken {
          result(["platform": "ios", "token": token])
          return
        }
        self.pendingTokenResults.append(result)
        UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .badge, .sound]
        ) { _, _ in
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
      case "deleteToken":
        UIApplication.shared.unregisterForRemoteNotifications()
        self.apnsToken = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    for (method, payload) in pendingPushEvents {
      channel.invokeMethod(method, arguments: payload)
    }
    pendingPushEvents.removeAll()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    apnsToken = token
    let response: [String: Any] = ["platform": "ios", "token": token]
    pendingTokenResults.forEach { $0(response) }
    pendingTokenResults.removeAll()
    queuePushEvent("token", payload: response)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
    pendingTokenResults.forEach {
      $0(FlutterError(code: "push_token", message: error.localizedDescription, details: nil))
    }
    pendingTokenResults.removeAll()
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    queuePushEvent("message", payload: pushPayload(userInfo))
    completionHandler(.newData)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let info = notification.request.content.userInfo
    guard isHermesRemotePush(info) else {
      super.userNotificationCenter(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
      return
    }
    queuePushEvent(
      "message",
      payload: pushPayload(
        info,
        title: notification.request.content.title,
        body: notification.request.content.body
      )
    )
    completionHandler([.banner, .sound, .badge])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    guard isHermesRemotePush(info) else {
      super.userNotificationCenter(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
      return
    }
    queuePushEvent(
      "tap",
      payload: pushPayload(
        info,
        title: response.notification.request.content.title,
        body: response.notification.request.content.body
      )
    )
    completionHandler()
  }

  private func isHermesRemotePush(_ info: [AnyHashable: Any]) -> Bool {
    return info["notification_id"] != nil ||
      info["event_type"] != nil ||
      info["session_id"] != nil
  }

  private func pushPayload(
    _ info: [AnyHashable: Any],
    title: String? = nil,
    body: String? = nil
  ) -> [String: Any] {
    var payload: [String: Any] = [:]
    for (key, value) in info where key.description != "aps" {
      if value is String || value is NSNumber || value is Bool {
        payload[key.description] = value
      }
    }
    if let title, !title.isEmpty { payload["title"] = title }
    if let body, !body.isEmpty { payload["body"] = body }
    return payload
  }

  private func queuePushEvent(_ method: String, payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if let channel = self.pushChannel {
        channel.invokeMethod(method, arguments: payload)
      } else {
        self.pendingPushEvents.append((method, payload))
      }
    }
  }
}
