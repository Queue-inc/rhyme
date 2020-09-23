import UIKit
import WebKit
import FirebaseInstanceID
import Reachability

open class RhymeViewController: UIViewController {
    
    open var url: URL?
    open var delegate: UNUserNotificationCenterDelegate?
    open var webView: WKWebView?
    var firebaseToken: String = ""
    var launchScreen: UIView?
    let reachability = try! Reachability()
    var alert: UIAlertController?
    var connection: Reachability.Connection = .unavailable
    
    open override func viewDidLoad() {
        reachability.whenReachable = { reachability in
            if self.connection == .unavailable {
                print("Reachable")
                if let alert = self.alert {
                    alert.dismiss(animated: true)
                    self.alert = nil
                }
                if let lastUrl = DataUtil.url {
                    self.webView?.load(URLRequest(url: lastUrl))
                } else if let url = self.url {
                    self.webView?.load(URLRequest(url: url))
                } else {
                    self.webView?.reload()
                }
                self.connection = reachability.connection
            }
            
        }
        reachability.whenUnreachable = { reachability in
            print("Not reachable")
            self.webView?.reload()
            self.connection = reachability.connection
        }
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
        if let url = url {
            let webConfig: WKWebViewConfiguration = WKWebViewConfiguration()
            let userController: WKUserContentController = WKUserContentController()
            userController.add(self, name: "FCM")
            webConfig.userContentController = userController
            webView = WKWebView(frame: self.view.frame, configuration: webConfig)
            webView?.navigationDelegate = self
            if let webView = webView {
                if let lastUrl = DataUtil.url {
                    print("lastUrl: \(lastUrl)")
                    webView.load(URLRequest(url: lastUrl))
                } else {
                    print("url: \(url)")
                    webView.load(URLRequest(url: url))
                }
                webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
                webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
                self.view.addSubview(webView)
            }
        }
        launchScreen = ViewUtil.launchScreen
        if let launchScreen = launchScreen {
            view.addSubview(launchScreen)
            NSLayoutConstraint.activate([
                launchScreen.topAnchor.constraint(equalTo: view.topAnchor),
                launchScreen.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                launchScreen.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                launchScreen.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            view.bringSubview(toFront: launchScreen)
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            assertionFailure()
            return
        }
        
        if let webView = webView {
            switch keyPath {
            case #keyPath(WKWebView.isLoading):
                if !webView.isLoading {
                    launchScreen?.removeFromSuperview()
                }
            case #keyPath(WKWebView.url):
                if let key = change?[NSKeyValueChangeKey.newKey] as? URL {
                    DataUtil.url = key
                }
            default:
                break
            }
        }
    }
    
}

extension RhymeViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let delegate = delegate, message.name == "FCM" {
            if let body = message.body as? String {
                if body == "START_RECEIVING" {
                    FirebaseUtil.confirmNotification(delegate: delegate)
                    InstanceID.instanceID().instanceID { (result, error) in
                        if let error = error {
                            print("Error fetching remote instance ID: \(error)")
                        } else if let result = result {
                            print("Remote instance ID token: \(result.token)")
                            let firebaseToken = "Remote InstanceID token: \(result.token)"
                            self.firebaseToken = firebaseToken
                        }
                    }
                } else if body.contains("TOPIC:") {
                    let bodies = body.components(separatedBy: ":")
                    FirebaseUtil.registerTopic(topic: bodies[1])
                }
            }
        }
    }
}

extension RhymeViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let code = (error as NSError).code
        print(code)
        if code == -1001 || code == -1003 || code == -1009 || code == -1100 {
            alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            if let alert = alert {
                present(alert, animated: true)
            }
        }
    }
}

