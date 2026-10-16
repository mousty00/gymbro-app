import ActivityKit
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // before launch ends, so a tap on a push that started the app is delivered too
    UNUserNotificationCenter.current().delegate = PushChannel.shared
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RepBirdsPush") {
      PushChannel.shared.attach(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RepBirdsRestActivity") {
      RestActivityChannel.attach(messenger: registrar.messenger())
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    PushChannel.shared.didRegister(deviceToken: deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    PushChannel.shared.didFailToRegister(error: error)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

/// Push via APNs, without Firebase: hands the device token to Dart (`repbirds/push`, see
/// lib/core/push/push_service.dart) and forwards incoming and tapped notifications.
final class PushChannel: NSObject, UNUserNotificationCenterDelegate {
  static let shared = PushChannel()

  private var channel: FlutterMethodChannel?
  private var token: String?
  private var pendingTokenResults: [FlutterResult] = []
  /// A tap that arrived before Dart asked for it (e.g. the push that launched the app).
  private var pendingOpened: [String: Any]?
  private var dartReady = false

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "repbirds/push", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    case "getToken":
      if let token = token {
        result(token)
        return
      }
      pendingTokenResults.append(result)
      UIApplication.shared.registerForRemoteNotifications()
    case "getInitialMessage":
      dartReady = true
      result(pendingOpened)
      pendingOpened = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func didRegister(deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    let changed = token != nil && token != hex
    token = hex
    pendingTokenResults.forEach { $0(hex) }
    pendingTokenResults.removeAll()
    if changed { channel?.invokeMethod("onToken", arguments: hex) }
  }

  func didFailToRegister(error: Error) {
    let failure = FlutterError(code: "apns", message: error.localizedDescription, details: nil)
    pendingTokenResults.forEach { $0(failure) }
    pendingTokenResults.removeAll()
  }

  // App in foreground: Dart shows its own banner and refreshes the lists.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    channel?.invokeMethod("onMessage", arguments: Self.message(notification.request.content))
    completionHandler([])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let message = Self.message(response.notification.request.content)
    if dartReady, let channel = channel {
      channel.invokeMethod("onOpened", arguments: message)
    } else {
      pendingOpened = message
    }
    completionHandler()
  }

  private static func message(_ content: UNNotificationContent) -> [String: Any] {
    var data: [String: String] = [:]
    for (key, value) in content.userInfo {
      if let key = key as? String, key != "aps" { data[key] = "\(value)" }
    }
    return ["title": content.title, "body": content.body, "data": data]
  }
}

/// Live Activity del recupero (`repbirds/rest_activity`, vedi lib/core/notifications/rest_alarm.dart):
/// il conto alla rovescia resta visibile nella schermata di blocco e nella Dynamic Island.
enum RestActivityChannel {
  static func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "repbirds/rest_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else { return result(nil) }
      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any] ?? [:]
        let ms = (args["endsAt"] as? NSNumber)?.doubleValue ?? 0
        start(
          endsAt: Date(timeIntervalSince1970: ms / 1000),
          title: args["title"] as? String ?? "",
          subtitle: args["subtitle"] as? String ?? "")
        result(nil)
      case "end":
        endAll()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 16.2, *)
  private static func start(endsAt: Date, title: String, subtitle: String) {
    endAll()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let content = ActivityContent(
      state: RestActivityAttributes.ContentState(endsAt: endsAt),
      // dopo la fine il sistema la mostra come scaduta
      staleDate: endsAt)
    _ = try? Activity.request(
      attributes: RestActivityAttributes(title: title, subtitle: subtitle), content: content)
  }

  @available(iOS 16.2, *)
  private static func endAll() {
    for activity in Activity<RestActivityAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
