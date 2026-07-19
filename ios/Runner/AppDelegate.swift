import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Live Location map tile (docs/06-deviations.md). This key needs its
    // own iOS-restriction (bundle ID) in Google Cloud Console — it cannot
    // share an HTTP-referrer restriction with the web key of the same
    // value; get a separate key per platform before shipping to app stores.
    GMSServices.provideAPIKey("AIzaSyCVIrqz2CResntrolbXTUXl7c9jj8BJb-8")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
