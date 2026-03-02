import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure audio session for background audio playback.
    // This is what allows Xbox Cloud Gaming audio to continue when the user
    // presses the Home button — matching the Android APK behaviour.
    configureAudioSession()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      // .playback category: audio continues in background
      // .mixWithOthers option: doesn't kill music/podcasts already playing
      // .allowBluetooth: routes audio to AirPods / Bluetooth controllers
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers, .allowBluetooth, .allowAirPlay]
      )
      try session.setActive(true)
    } catch {
      print("[BxC] AVAudioSession configuration failed: \(error)")
    }
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    // Keep audio session active when entering background
    super.applicationWillResignActive(application)
    try? AVAudioSession.sharedInstance().setActive(true)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    // Re-activate audio session when returning to foreground
    super.applicationDidBecomeActive(application)
    try? AVAudioSession.sharedInstance().setActive(true)
  }
}
