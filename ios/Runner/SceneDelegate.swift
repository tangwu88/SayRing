import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let engine = appDelegate.flutterEngine
    else {
      return
    }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )
    self.window = window
    window.makeKeyAndVisible()
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      URLContexts.contains(where: { appDelegate.handlePaymentOpenURL($0.url) }) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      appDelegate.handlePaymentUniversalLink(userActivity) {
      return
    }
    super.scene(scene, continue: userActivity)
  }
}
