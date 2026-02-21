import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // [FIX] Registra il task identifier PRIMA di tutto il resto
    // Deve corrispondere a quello in Info.plist
    WorkmanagerPlugin.registerTask(withIdentifier: "workmanager.background.task")

    GeneratedPluginRegistrant.register(with: self)

    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // MethodChannel per donare NSUserActivity shortcuts a Siri
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let shortcutsChannel = FlutterMethodChannel(
        name: "kybo/shortcuts",
        binaryMessenger: controller.binaryMessenger
      )
      shortcutsChannel.setMethodCallHandler { [weak self] call, result in
        if call.method == "donateShortcut", let activityType = call.arguments as? String {
          self?.donateActivity(activityType: activityType, controller: controller)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Invocato da Siri quando l'utente usa uno shortcut
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let deepLink: String
    switch userActivity.activityType {
    case "it.kybo.app.viewDiet":
      deepLink = "kybo://diet"
    case "it.kybo.app.viewSuggestions":
      deepLink = "kybo://suggestions"
    default:
      return false
    }
    if let url = URL(string: deepLink) {
      application.open(url, options: [:], completionHandler: nil)
    }
    return true
  }

  // Crea e dona un NSUserActivity a Siri
  private func donateActivity(activityType: String, controller: FlutterViewController) {
    let activity = NSUserActivity(activityType: activityType)
    let isDiet = activityType == "it.kybo.app.viewDiet"
    let title = isDiet ? "Vedi la mia dieta" : "Suggerimenti pasti"
    let phrase = isDiet ? "Vedi la mia dieta" : "Suggerimenti pasti"
    activity.title = title
    activity.isEligibleForPrediction = true
    activity.isEligibleForSearch = true
    activity.persistentIdentifier = activityType
    if #available(iOS 12.0, *) {
      activity.suggestedInvocationPhrase = phrase
    }
    controller.userActivity = activity
    activity.becomeCurrent()
  }
}
