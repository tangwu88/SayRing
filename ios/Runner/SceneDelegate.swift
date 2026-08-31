import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
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
