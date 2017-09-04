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
import CoreImage

open class ProfileController: UIViewController {

    fileprivate var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    fileprivate lazy var avatarImageView: AvatarImageView = {
        let view = AvatarImageView(withAutoLayout: true)

        return view
    }()

    fileprivate lazy var nameLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.numberOfLines = 0
        view.font = Theme.regular(size: 24)

        return view
    }()

    fileprivate lazy var usernameLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.numberOfLines = 0
        view.font = Theme.regular(size: 16)
        view.textColor = Theme.greyTextColor

        return view
    }()

    fileprivate lazy var editProfileButton: UIButton = {
        let view = UIButton(withAutoLayout: true)
        view.setAttributedTitle(NSAttributedString(string: "Edit Profile", attributes: [NSFontAttributeName: Theme.regular(size: 17), NSForegroundColorAttributeName: Theme.tintColor]), for: .normal)
        view.setAttributedTitle(NSAttributedString(string: "Edit Profile", attributes: [NSFontAttributeName: Theme.regular(size: 17), NSForegroundColorAttributeName: Theme.lightGreyTextColor]), for: .highlighted)
        view.addTarget(self, action: #selector(didTapEditProfileButton), for: .touchUpInside)

        return view
    }()

    fileprivate lazy var editSeparatorView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.borderColor
        view.set(height: 1.0 / UIScreen.main.scale)

        return view
    }()

    fileprivate lazy var aboutContentLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.font = Theme.regular(size: 17)
        view.numberOfLines = 0

        return view
    }()

    fileprivate lazy var locationContentLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.font = Theme.regular(size: 16)
        view.textColor = Theme.lightGreyTextColor
        view.numberOfLines = 0

        return view
    }()

    fileprivate lazy var contentBackgroundView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.viewBackgroundColor

        return view
    }()

    fileprivate lazy var contentSeparatorView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.settingsBackgroundColor
        view.layer.borderColor = Theme.borderColor.cgColor
        view.layer.borderWidth = 1.0 / UIScreen.main.scale
        view.set(height: 1.0 / UIScreen.main.scale)

        return view
    }()

    fileprivate lazy var reputationSeparatorView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.settingsBackgroundColor
        view.layer.borderColor = Theme.borderColor.cgColor
        view.layer.borderWidth = 1.0 / UIScreen.main.scale
        view.set(height: 1.0 / UIScreen.main.scale)

        return view
    }()

    fileprivate lazy var bottomSeparatorView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.settingsBackgroundColor
        view.layer.borderColor = Theme.borderColor.cgColor
        view.layer.borderWidth = 1.0 / UIScreen.main.scale
        view.set(height: 1.0 / UIScreen.main.scale)

        return view
    }()

    fileprivate lazy var reputationView: ReputationView = {
        let view = ReputationView(withAutoLayout: true)

        return view
    }()

    fileprivate lazy var reputationBackgroundView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.viewBackgroundColor

        return view
    }()

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.alwaysBounceVertical = true
        view.showsVerticalScrollIndicator = true
        view.delaysContentTouches = false
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 49, right: 0)

        return view
    }()

    private lazy var container: UIView = {
        let view = UIView()

        return view
    }()

    public init() {
        super.init(nibName: nil, bundle: nil)

        edgesForExtendedLayout = .bottom
        title = "Profile"
    }

    public required init?(coder _: NSCoder) {
        fatalError("")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.settingsBackgroundColor

        addSubviewsAndConstraints()

        reputationView.setScore(.zero)
        updateReputation()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let name = TokenUser.current?.name, !name.isEmpty, let username = TokenUser.current?.displayUsername {
            nameLabel.text = name
            usernameLabel.text = username
        } else if let username = TokenUser.current?.displayUsername {
            usernameLabel.text = nil
            nameLabel.text = username
        }

        aboutContentLabel.text = TokenUser.current?.about
        locationContentLabel.text = TokenUser.current?.location

        if let path = TokenUser.current?.avatarPath as String? {
            AvatarManager.shared.avatar(for: path) { [weak self] image, _ in
                self?.avatarImageView.image = image
            }
        }
    }

    fileprivate func addSubviewsAndConstraints() {
        let margin: CGFloat = 15
        let avatarSize = CGSize(width: 60, height: 60)

        view.addSubview(scrollView)
        scrollView.edges(to: view)

        scrollView.addSubview(container)
        container.edges(to: scrollView)
        container.width(to: scrollView)

        container.addSubview(contentBackgroundView)

        contentBackgroundView.top(to: container)
        contentBackgroundView.left(to: container)
        contentBackgroundView.right(to: container)

        contentBackgroundView.addSubview(avatarImageView)
        contentBackgroundView.addSubview(nameLabel)
        contentBackgroundView.addSubview(usernameLabel)
        contentBackgroundView.addSubview(aboutContentLabel)
        contentBackgroundView.addSubview(locationContentLabel)
        contentBackgroundView.addSubview(editSeparatorView)
        contentBackgroundView.addSubview(editProfileButton)
        contentBackgroundView.addSubview(contentSeparatorView)

        avatarImageView.size(avatarSize)
        avatarImageView.origin(to: contentBackgroundView, insets: CGVector(dx: margin, dy: margin * 2))

        let nameContainer = UILayoutGuide()
        contentBackgroundView.addLayoutGuide(nameContainer)

        nameContainer.top(to: contentBackgroundView, offset: margin * 2)
        nameContainer.leftToRight(of: avatarImageView, offset: margin)
        nameContainer.right(to: contentBackgroundView, offset: -margin)

        nameLabel.height(25, relation: .equalOrGreater, priority: .high)
        nameLabel.top(to: nameContainer)
        nameLabel.left(to: nameContainer)
        nameLabel.right(to: nameContainer)

        usernameLabel.height(25, relation: .equalOrGreater, priority: .high)
        usernameLabel.topToBottom(of: nameLabel, offset: margin)
        usernameLabel.left(to: nameContainer)
        usernameLabel.bottom(to: nameContainer)
        usernameLabel.right(to: nameContainer)

        aboutContentLabel.topToBottom(of: nameContainer, offset: margin)
        aboutContentLabel.left(to: contentBackgroundView, offset: margin)
        aboutContentLabel.right(to: contentBackgroundView, offset: -margin)

        locationContentLabel.topToBottom(of: aboutContentLabel, offset: margin)
        locationContentLabel.left(to: contentBackgroundView, offset: margin)
        locationContentLabel.right(to: contentBackgroundView, offset: -margin)

        editSeparatorView.height(Theme.borderHeight)
        editSeparatorView.topToBottom(of: locationContentLabel, offset: margin)
        editSeparatorView.left(to: contentBackgroundView)
        editSeparatorView.right(to: contentBackgroundView)

        editProfileButton.height(50)
        editProfileButton.topToBottom(of: editSeparatorView)
        editProfileButton.left(to: contentBackgroundView)
        editProfileButton.right(to: contentBackgroundView)

        contentSeparatorView.height(Theme.borderHeight)
        contentSeparatorView.topToBottom(of: editProfileButton)
        contentSeparatorView.left(to: contentBackgroundView)
        contentSeparatorView.right(to: contentBackgroundView)
        contentSeparatorView.bottom(to: contentBackgroundView)

        container.addSubview(reputationBackgroundView)

        reputationBackgroundView.topToBottom(of: contentBackgroundView, offset: 66)
        reputationBackgroundView.left(to: container)
        reputationBackgroundView.bottom(to: container)
        reputationBackgroundView.right(to: container)

        reputationBackgroundView.addSubview(reputationSeparatorView)
        reputationBackgroundView.addSubview(reputationView)
        reputationBackgroundView.addSubview(bottomSeparatorView)

        reputationSeparatorView.height(Theme.borderHeight)
        reputationSeparatorView.top(to: reputationBackgroundView)
        reputationSeparatorView.left(to: reputationBackgroundView)
        reputationSeparatorView.right(to: reputationBackgroundView)

        reputationView.topToBottom(of: reputationSeparatorView, offset: 40)
        reputationView.left(to: reputationBackgroundView, offset: 34)
        reputationView.right(to: reputationBackgroundView, offset: -40)

        bottomSeparatorView.height(Theme.borderHeight)
        bottomSeparatorView.topToBottom(of: reputationView, offset: 40)
        bottomSeparatorView.left(to: reputationBackgroundView)
        bottomSeparatorView.right(to: reputationBackgroundView)
        bottomSeparatorView.bottom(to: reputationBackgroundView)
    }

    fileprivate func updateReputation() {
        guard let currentUser = TokenUser.current as TokenUser? else { return }

        RatingsClient.shared.scores(for: currentUser.address) { [weak self] ratingScore in
            self?.reputationView.setScore(ratingScore)
        }
    }

    @objc
    fileprivate func didTapEditProfileButton() {
        let editController = ProfileEditController()
        navigationController?.pushViewController(editController, animated: true)
    }
}
