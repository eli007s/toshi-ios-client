// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import UIKit
import SweetUIKit
import WebKit

class SOFAWebController: UIViewController {

    enum Method: String {
        case getAccounts
        case signTransaction
        case approveTransaction
    }

    fileprivate var etherAPIClient: EthereumAPIClient {
        return EthereumAPIClient.shared
    }

    fileprivate let rcpUrl = ToshiWebviewRPCURLPath

    fileprivate var callbackId = ""

    fileprivate lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()

        var js = "window.SOFA = {config: {rcpUrl: '" + self.rcpUrl + "'}}; "

        if let filepath = Bundle.main.path(forResource: "sofa-web3", ofType: "js") {
            do {
                js += try String(contentsOfFile: filepath)
                print("Loaded sofa.js")
            } catch {
                print("Failed to load sofa.js")
            }
        } else {
            print("Sofa.js not found in bundle")
        }

        var userScript: WKUserScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)

        configuration.userContentController.add(self, name: Method.getAccounts.rawValue)
        configuration.userContentController.add(self, name: Method.signTransaction.rawValue)
        configuration.userContentController.add(self, name: Method.approveTransaction.rawValue)

        configuration.userContentController.addUserScript(userScript)

        let view = WKWebView(frame: self.view.frame, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.isScrollEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.navigationDelegate = self

        return view
    }()

    fileprivate lazy var backButton: UIButton = {
        let view = UIButton(type: .custom)
        view.bounds.size = CGSize(width: 44, height: 44)
        view.setImage(#imageLiteral(resourceName: "web_back").withRenderingMode(.alwaysTemplate), for: .normal)
        view.addTarget(self, action: #selector(self.didTapBackButton), for: .touchUpInside)

        return view
    }()

    fileprivate lazy var forwardButton: UIButton = {
        let view = UIButton(type: .custom)
        view.bounds.size = CGSize(width: 44, height: 44)
        view.setImage(#imageLiteral(resourceName: "web_forward").withRenderingMode(.alwaysTemplate), for: .normal)
        view.addTarget(self, action: #selector(self.didTapForwardButton), for: .touchUpInside)

        return view
    }()

    fileprivate lazy var backBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(customView: self.backButton)
    }()

    fileprivate lazy var forwardBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(customView: self.forwardButton)
    }()

    fileprivate lazy var toolbar: UIToolbar = {
        let view = UIToolbar(withAutoLayout: true)

        let share = UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil)
        let spacing = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let placeholder = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        placeholder.width = 44

        view.items = [self.backBarButtonItem, spacing, self.forwardBarButtonItem, spacing, share, spacing, placeholder]

        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(webView)
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            self.toolbar.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.toolbar.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self.toolbar.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        toolbar.set(height: 44)
        hidesBottomBarWhenPushed = true
        webView.fillSuperview()
    }

    public func load(url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        loadViewIfNeeded()
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }

    @objc
    fileprivate func didTapBackButton() {
        webView.goBack()
    }

    @objc
    fileprivate func didTapForwardButton() {
        webView.goForward()
    }
}

extension SOFAWebController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        backBarButtonItem.isEnabled = webView.canGoBack
        forwardBarButtonItem.isEnabled = webView.canGoForward
    }
}

extension SOFAWebController: WKScriptMessageHandler {
    fileprivate func jsCallback(callbackId: String, payload: String) {
        let js = "SOFA.callback(\"" + callbackId + "\",\"" + payload + "\")"

        webView.evaluateJavaScript("javascript:" + js) { jsReturnValue, error in
            if let error = error {
                print("Error: \(error)")
            } else if let newCount = jsReturnValue as? Int {
                print("Returned value: \(newCount)")
            } else {
                print("No return from JS")
            }
        }
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let method = Method(rawValue: message.name) else { return print("failed \(message.name)") }
        guard let callbackId = (message.body as? NSDictionary)?.value(forKey: "callback") as? String else { return print("missing callback id") }

        self.callbackId = callbackId

        switch method {
        case .getAccounts:
            let payload = "{\\\"error\\\": null, \\\"result\\\": [\\\"" + Cereal.shared.paymentAddress + "\\\"]}"
            jsCallback(callbackId: callbackId, payload: payload)

            break
        case .signTransaction:
            guard let messageBody = message.body as? [String: Any], let tx = messageBody["tx"] as? [String: Any] else {
                return
            }

            var parameters: [String: Any] = [:]
            if let from = tx["from"] {
                parameters["from"] = from
            }
            if let to = tx["to"] {
                parameters["to"] = to
            }
            if let value = tx["value"] {
                parameters["value"] = value
            } else {
                parameters["value"] = "0x0"
            }
            if let data = tx["data"] {
                parameters["data"] = data
            }
            if let gas = tx["gas"] {
                parameters["gas"] = gas
            }
            if let gasPrice = tx["gasPrice"] {
                parameters["gasPrice"] = gasPrice
            }

            if let to = tx["to"] as? String {
                IDAPIClient.shared.retrieveUser(username: to) { [weak self] user in
                    var userInfo = UserInfo(address: to, paymentAddress: to, avatarPath: nil, name: nil, username: to, isLocal: false)

                    if let user = user as TokenUser? {
                        userInfo.avatarPath = user.avatarPath
                        userInfo.username = user.username
                        userInfo.name = user.name
                        userInfo.isLocal = true
                    }
                    self?.displayPaymentConfirmation(userInfo: userInfo, parameters: parameters)
                }
            } else {
                let userInfo = UserInfo(address: "", paymentAddress: "", avatarPath: nil, name: "New Contract", username: "", isLocal: false)
                displayPaymentConfirmation(userInfo: userInfo, parameters: parameters)
            }

            break
        case .approveTransaction:
            let payload = "{\\\"error\\\": null, \\\"result\\\": true}"
            jsCallback(callbackId: callbackId, payload: payload)

            break
        }
    }
}

extension SOFAWebController: PaymentPresentable {
    func paymentApproved(with parameters: [String: Any], userInfo _: UserInfo) {
        etherAPIClient.createUnsignedTransaction(parameters: parameters) { [weak self] transaction, _ in
            guard let strongSelf = self else { return }

            var payload: String

            if let tx = transaction {
                let signedTransaction = "0x\(Cereal.shared.signWithWallet(hex: tx))"
                payload = "{\\\"error\\\": null, \\\"result\\\": [\\\"" + tx + "\\\", \\\"" + signedTransaction + "\\\"]}"
            } else {
                payload = "{\\\"error\\\": \\\"Error constructing tx skeleton\\\", \\\"result\\\": null}"
            }

            strongSelf.jsCallback(callbackId: strongSelf.callbackId, payload: payload)
        }
    }

    func paymentDeclined() {
        let payload = "{\\\"error\\\": \\\"Transaction declined by user\\\", \\\"result\\\": null}"
        jsCallback(callbackId: callbackId, payload: payload)
    }
}
