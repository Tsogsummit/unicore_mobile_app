import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Activate the Apple Watch connectivity session.
    WatchConnector.shared.activate()

    // Bridge from Flutter (WatchSync) to WatchConnector so the phone can push
    // the signed-in credentials to the paired watch.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "systems.unicore/watch",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "syncCredentials":
          guard
            let args = call.arguments as? [String: Any],
            let username = args["username"] as? String,
            let password = args["password"] as? String
          else {
            result(FlutterError(code: "bad_args", message: "username/password required", details: nil))
            return
          }
          WatchConnector.shared.sync(username: username, password: password)
          result(nil)
        case "clearCredentials":
          WatchConnector.shared.clear()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
