import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        (window?.rootViewController as? ViewController)?.recheckEnabledOnly()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (window?.rootViewController as? ViewController)?.saveWebViewState()
    }
}
