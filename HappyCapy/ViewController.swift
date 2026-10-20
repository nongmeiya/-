import UIKit
import WebKit
import CryptoKit

final class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
    private let homeURL = URL(string: "https://hg.xxrmb.com:9443")!
    private let controlURL = URL(string: "https://raw.githubusercontent.com/nongmeiya/-/happycapy-ios/app-control.json")!
    private let fallbackPasswordHash = "0402de472e8aaa701b181a216ffec79a6d892e8e00922f1cac52fa66421d96ca"
    private let defaultBlockedMessage = "应用已停用"

    private var webView: WKWebView!
    private var progressObservation: NSKeyValueObservation?
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private let gateView = UIView()
    private let gateTitleLabel = UILabel()
    private let gateStatusLabel = UILabel()
    private let passwordField = UITextField()
    private let enterButton = UIButton(type: .system)
    private let gateRetryButton = UIButton(type: .system)
    private var expectedPasswordHash = ""
    private var didEnterApp = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .all
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureWebView()
        configureErrorView()
        configureProgressView()
        configureGateView()
        startGateCheck()
    }

    deinit {
        progressObservation?.invalidate()
    }

    // MARK: - Gate (password + remote control)

    private func configureGateView() {
        gateView.translatesAutoresizingMaskIntoConstraints = false
        gateView.backgroundColor = .black
        view.addSubview(gateView)
        NSLayoutConstraint.activate([
            gateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gateView.topAnchor.constraint(equalTo: view.topAnchor),
            gateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        gateTitleLabel.text = "小新短剧"
        gateTitleLabel.textColor = .white
        gateTitleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        gateTitleLabel.textAlignment = .center
        gateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        gateView.addSubview(gateTitleLabel)

        gateStatusLabel.text = "正在验证授权…"
        gateStatusLabel.textColor = .lightGray
        gateStatusLabel.font = .systemFont(ofSize: 15)
        gateStatusLabel.textAlignment = .center
        gateStatusLabel.numberOfLines = 0
        gateStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        gateView.addSubview(gateStatusLabel)

        passwordField.isSecureTextEntry = true
        passwordField.placeholder = "请输入密码"
        passwordField.textColor = .white
        passwordField.backgroundColor = UIColor(white: 0.15, alpha: 1)
        passwordField.layer.cornerRadius = 10
        passwordField.textAlignment = .center
        passwordField.font = .systemFont(ofSize: 17)
        passwordField.autocorrectionType = .no
        passwordField.autocapitalizationType = .none
        passwordField.returnKeyType = .go
        passwordField.addTarget(self, action: #selector(submitPassword), for: .editingDidEndOnExit)
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        passwordField.isHidden = true
        gateView.addSubview(passwordField)

        enterButton.setTitle("进入", for: .normal)
        enterButton.setTitleColor(.white, for: .normal)
        enterButton.backgroundColor = .systemOrange
        enterButton.layer.cornerRadius = 10
        enterButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        enterButton.addTarget(self, action: #selector(submitPassword), for: .touchUpInside)
        enterButton.translatesAutoresizingMaskIntoConstraints = false
        enterButton.isHidden = true
        gateView.addSubview(enterButton)

        gateRetryButton.setTitle("重新检测", for: .normal)
        gateRetryButton.setTitleColor(.systemOrange, for: .normal)
        gateRetryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        gateRetryButton.addTarget(self, action: #selector(startGateCheck), for: .touchUpInside)
        gateRetryButton.translatesAutoresizingMaskIntoConstraints = false
        gateRetryButton.isHidden = true
        gateView.addSubview(gateRetryButton)

        NSLayoutConstraint.activate([
            gateTitleLabel.centerXAnchor.constraint(equalTo: gateView.centerXAnchor),
            gateTitleLabel.centerYAnchor.constraint(equalTo: gateView.centerYAnchor, constant: -110),
            gateStatusLabel.centerXAnchor.constraint(equalTo: gateView.centerXAnchor),
            gateStatusLabel.topAnchor.constraint(equalTo: gateTitleLabel.bottomAnchor, constant: 16),
            gateStatusLabel.leadingAnchor.constraint(equalTo: gateView.leadingAnchor, constant: 40),
            gateStatusLabel.trailingAnchor.constraint(equalTo: gateView.trailingAnchor, constant: -40),
            passwordField.centerXAnchor.constraint(equalTo: gateView.centerXAnchor),
            passwordField.topAnchor.constraint(equalTo: gateStatusLabel.bottomAnchor, constant: 26),
            passwordField.widthAnchor.constraint(equalToConstant: 260),
            passwordField.heightAnchor.constraint(equalToConstant: 48),
            enterButton.centerXAnchor.constraint(equalTo: gateView.centerXAnchor),
            enterButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 18),
            enterButton.widthAnchor.constraint(equalToConstant: 260),
            enterButton.heightAnchor.constraint(equalToConstant: 48),
            gateRetryButton.centerXAnchor.constraint(equalTo: gateView.centerXAnchor),
            gateRetryButton.topAnchor.constraint(equalTo: gateStatusLabel.bottomAnchor, constant: 26)
        ])
    }

    @objc private func startGateCheck() {
        gateView.isHidden = false
        view.bringSubviewToFront(gateView)
        gateRetryButton.isHidden = true
        passwordField.isHidden = true
        enterButton.isHidden = true
        gateStatusLabel.text = "正在验证授权…"
        fetchControl { [weak self] control in
            self?.applyControl(control, fullGate: true)
        }
    }

    /// Called when the app returns to the foreground: only enforces the remote on/off switch.
    func recheckEnabledOnly() {
        fetchControl { [weak self] control in
            guard let self else { return }
            if control.enabled == false {
                self.webView.stopLoading()
                self.showBlocked(message: control.message ?? self.defaultBlockedMessage)
            }
        }
    }

    private struct Control {
        var enabled: Bool
        var passwordHash: String
        var message: String?
    }

    private func fetchControl(completion: @escaping (Control) -> Void) {
        var components = URLComponents(url: controlURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")]
        let url = components?.url ?? controlURL
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 6)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data, let control = Self.parseControl(data) {
                UserDefaults.standard.set(data, forKey: "gate.controlCache")
                DispatchQueue.main.async { completion(control) }
                return
            }
            if let cached = UserDefaults.standard.data(forKey: "gate.controlCache"),
               let control = Self.parseControl(cached) {
                DispatchQueue.main.async { completion(control) }
                return
            }
            DispatchQueue.main.async {
                completion(Control(enabled: true, passwordHash: self.fallbackPasswordHash, message: nil))
            }
        }.resume()
    }

    private static func parseControl(_ data: Data) -> Control? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let enabled = dict["enabled"] as? Bool ?? true
        let hash = (dict["password_sha256"] as? String ?? "").lowercased()
        let message = dict["message"] as? String
        return Control(enabled: enabled, passwordHash: hash, message: message)
    }

    private func applyControl(_ control: Control, fullGate: Bool) {
        if !control.enabled {
            showBlocked(message: control.message ?? defaultBlockedMessage)
            return
        }
        let hash = control.passwordHash.isEmpty ? fallbackPasswordHash : control.passwordHash
        expectedPasswordHash = hash
        if UserDefaults.standard.string(forKey: "gate.unlockedHash") == hash {
            enterApp()
            return
        }
        gateStatusLabel.text = "请输入密码"
        passwordField.isHidden = false
        enterButton.isHidden = false
        passwordField.becomeFirstResponder()
    }

    private func showBlocked(message: String) {
        gateView.isHidden = false
        view.bringSubviewToFront(gateView)
        passwordField.isHidden = true
        enterButton.isHidden = true
        passwordField.resignFirstResponder()
        gateStatusLabel.text = message
        gateRetryButton.isHidden = false
    }

    @objc private func submitPassword() {
        let input = passwordField.text ?? ""
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        if hex == expectedPasswordHash {
            UserDefaults.standard.set(expectedPasswordHash, forKey: "gate.unlockedHash")
            passwordField.text = ""
            passwordField.resignFirstResponder()
            enterApp()
        } else {
            gateStatusLabel.text = "密码不正确，请重试"
            passwordField.text = ""
        }
    }

    private func enterApp() {
        gateView.isHidden = true
        if !didEnterApp {
            didEnterApp = true
            loadHome()
        }
    }

    // MARK: - Web view

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptEnabled = true
        configuration.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let swipeBack = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeBack(_:)))
        swipeBack.delegate = self
        swipeBack.maximumNumberOfTouches = 1
        webView.addGestureRecognizer(swipeBack)

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progressView.progress = Float(webView.estimatedProgress)
                self?.progressView.isHidden = webView.estimatedProgress >= 1.0
            }
        }
    }

    @objc private func handleSwipeBack(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let translation = gesture.translation(in: webView)
        let velocity = gesture.velocity(in: webView)
        if translation.x > 90, abs(translation.y) < 60, velocity.x > 0, webView.canGoBack {
            webView.goBack()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func configureProgressView() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemOrange
        progressView.trackTintColor = .clear
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func configureErrorView() {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = .black
        errorView.isHidden = true
        view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        errorLabel.text = "网络连接失败"
        errorLabel.textColor = .white
        errorLabel.font = .systemFont(ofSize: 18, weight: .medium)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(errorLabel)

        retryButton.setTitle("重新加载", for: .normal)
        retryButton.setTitleColor(.systemOrange, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: errorView.centerYAnchor, constant: -24),
            retryButton.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 18)
        ])
    }

    private func loadHome() {
        errorView.isHidden = true
        webView.load(URLRequest(url: homeURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    @objc private func retry() {
        loadHome()
    }

    func saveWebViewState() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { _ in }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorView.isHidden = true
        progressView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showErrorIfNeeded(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showErrorIfNeeded(error)
    }

    private func showErrorIfNeeded(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        progressView.isHidden = true
        errorView.isHidden = false
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

}
