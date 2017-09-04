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
import TinyConstraints

class AddMoneyController: UIViewController {

    private var items: [AddMoneyItem] = []

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.alwaysBounceVertical = true
        view.showsVerticalScrollIndicator = true
        view.delaysContentTouches = false
        view.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 40, right: 0)

        return view
    }()

    private lazy var stackView: UIStackView = UIStackView(with: self.items)
    
    private var isAccountSecured: Bool {
        return TokenUser.current?.verified ?? false
    }

    convenience init(for username: String, name _: String) {
        self.init(nibName: nil, bundle: nil)

        title = "Add Money"

        items = [
            .header("Add money to my Wallet", "You can add money to your account in a variety of ways."),
            .bulletPoint("1. Send ETH from another wallet", "Send to this address to top up your wallet:\n\n\(Cereal.shared.paymentAddress)"),
            .copyToClipBoard("Copy to clipboard", "Copied", #selector(copyToClipBoard(_:))),
            .QRCode(UIImage.imageQRCode(for: "\(QRCodeController.addUsernameBasePath)\(username)", resizeRate: 20.0)),
            .warning("Do not send ETH from Mainnet. Toshi is currently using Ropsten revival Testnet."),
            .bulletPoint("2. Find a local exchanger", "Find a local exchanger of Ethereum in your country. You can give them cash and they will send you Ethereum."),
            .bulletPoint("3. Earn money", "Install an app that lets you earn Ethereum."),
            .bulletPoint("4. Request money from a friend", "Send a payment request to a friend on Toshi.")
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.settingsBackgroundColor

        view.addSubview(scrollView)
        scrollView.edges(to: view)

        scrollView.addSubview(stackView)
        stackView.edges(to: scrollView)
        stackView.width(to: scrollView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isAccountSecured {
            let alert = UIAlertController(title: Localized("settings_deposit_error_title"), message: Localized("settings_deposit_error_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("settings_deposit_error_action_cancel"), style: .default, handler: { _ in
                alert.dismiss(animated: true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: Localized("settings_deposit_error_action_backup"), style: .default, handler: { _ in
                let passphraseEnableController = PassphraseEnableController()
                let navigationController = UINavigationController(rootViewController: passphraseEnableController)
                Navigator.presentModally(navigationController)
            }))
            Navigator.presentModally(alert)
        }
    }

    func copyToClipBoard(_ button: ConfirmationButton) {
        UIPasteboard.general.string = Cereal.shared.paymentAddress

        DispatchQueue.main.asyncAfter(seconds: 0.1) {
            button.contentState = button.contentState == .actionable ? .confirmation : .actionable
        }
    }
}
