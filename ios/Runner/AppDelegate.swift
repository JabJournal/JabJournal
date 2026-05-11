import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "app.jabjournal/icon",
      binaryMessenger: controller.binaryMessenger
    )
    let iosIconName: [String: String] = [
      "forest":   "AppIconForest",
      "amethyst": "AppIconAmethyst",
      "slate":    "AppIconSlate",
    ]
    let variantForName: [String: String] = Dictionary(
      uniqueKeysWithValues: iosIconName.map { ($1, $0) }
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(UIApplication.shared.supportsAlternateIcons)

      case "getIcon":
        if let iosName = UIApplication.shared.alternateIconName {
          result(variantForName[iosName] ?? iosName)
        } else {
          result(nil)
        }

      case "setIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(code: "NOT_SUPPORTED",
                              message: "Alternate icons not supported on this device",
                              details: nil))
          return
        }
        let variant = call.arguments as? String
        let iosName = variant.flatMap { iosIconName[$0] }
        UIApplication.shared.setAlternateIconName(iosName) { error in
          if let error = error {
            result(FlutterError(code: "SET_FAILED",
                                message: error.localizedDescription,
                                details: nil))
          } else {
            result(nil)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return result
  }
}
