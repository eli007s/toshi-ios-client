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
import TinyConstraints

class PaymentConfirmationController: AlertController {

    static let contentWidth: CGFloat = 310

    fileprivate var userInfo: UserInfo
    fileprivate var value = NSDecimalNumber.zero

    fileprivate var review: String = ""

    fileprivate lazy var networkView: ActiveNetworkView = {
        self.defaultActiveNetworkView()
    }()

    init(userInfo: UserInfo, value: NSDecimalNumber) {
        self.userInfo = userInfo

        super.init(nibName: nil, bundle: nil)

        self.value = value

        modalPresentationStyle = .custom
        transitioningDelegate = self
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }

    func cancel(_: ActionButton) {
        dismiss(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCustomContentView()

        setupActiveNetworkView()

        showActiveNetworkViewIfNeeded()
    }

    fileprivate func setupCustomContentView() {
        if let customView = Bundle.main.loadNibNamed("PaymentRequestInfoView", owner: nil, options: nil)?.first as? PaymentRequestInfoView {

            customView.translatesAutoresizingMaskIntoConstraints = false
            customView.autoresizingMask = [.flexibleHeight, .flexibleWidth]

            customView.set(height: customView.frame.height + activeNetworkView.frame.height)
            if let path = self.userInfo.avatarPath as String? {
                AvatarManager.shared.avatar(for: path) { image, _ in
                    customView.userAvatarImageView.image = image
                }
            }

            customView.userDisplayNameLabel.text = userInfo.name
            customView.userNameLabel.text = userInfo.username
            customView.valueLabel.attributedText = EthereumConverter.balanceSparseAttributedString(forWei: value, exchangeRate: ExchangeRateClient.exchangeRate, width: customView.valueLabel.frame.width)

            customView.mode = (userInfo.isLocal == true) ? Mode.localUser : Mode.remoteUser

            customContentView = customView

            RatingsClient.shared.scores(for: userInfo.address) { [weak self] score in
                if let view = self?.customContentView as? PaymentRequestInfoView {
                    view.ratingView.set(rating: Float(score.averageRating), animated: true)
                    view.ratingCountLabel.text = "(\(score.reviewCount))"
                }
            }
        }
    }
}

extension PaymentConfirmationController: ActiveNetworkDisplaying {

    var activeNetworkView: ActiveNetworkView {
        return networkView
    }

    var activeNetworkViewConstraints: [NSLayoutConstraint] {
        return [activeNetworkView.top(to: view),
                activeNetworkView.left(to: view),
                activeNetworkView.right(to: view)]
    }
}
