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

/// Displays user's contacts.
class ContactCell: UITableViewCell {
    var contact: TokenUser? {
        didSet {
            if let contact = self.contact {
                if contact.name.isEmpty {
                    nameLabel.text = contact.displayUsername
                    usernameLabel.text = nil
                } else {
                    usernameLabel.text = contact.displayUsername
                    nameLabel.text = contact.name
                }

                AvatarManager.shared.avatar(for: contact.avatarPath) { [weak self] image, path in
                    if image != nil && contact.avatarPath == path {
                        self?.avatarImageView.image = image
                    }
                }

                return
            }

            usernameLabel.text = nil
            nameLabel.text = nil
            avatarImageView.image = nil
        }
    }

    lazy var nameLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.setContentHuggingPriority(UILayoutPriorityRequired, for: .horizontal)
        view.textColor = Theme.darkTextColor
        view.font = Theme.semibold(size: 15)

        return view
    }()

    lazy var usernameLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.setContentHuggingPriority(UILayoutPriorityDefaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
        view.textColor = Theme.greyTextColor
        view.font = Theme.regular(size: 14)

        return view
    }()

    lazy var avatarImageView: AvatarImageView = {
        let view = AvatarImageView(withAutoLayout: true)

        return view
    }()

    lazy var separatorView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.borderColor

        return view
    }()

    override func prepareForReuse() {
        super.prepareForReuse()

        avatarImageView.image = nil
        nameLabel.text = nil
        usernameLabel.text = nil
        contact = nil
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(avatarImageView)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(separatorView)

        let margin: CGFloat = 16.0
        let interLabelMargin: CGFloat = 6.0
        let imageSize: CGFloat = 44.0
        let height: CGFloat = 24.0

        avatarImageView.set(height: imageSize)
        avatarImageView.set(width: imageSize)
        avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        avatarImageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: margin).isActive = true

        nameLabel.heightAnchor.constraint(equalToConstant: height).isActive = true
        nameLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: margin).isActive = true
        nameLabel.leftAnchor.constraint(equalTo: avatarImageView.rightAnchor, constant: margin).isActive = true
        nameLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -margin).isActive = true

        usernameLabel.heightAnchor.constraint(equalToConstant: height).isActive = true
        usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: interLabelMargin).isActive = true
        usernameLabel.leftAnchor.constraint(equalTo: avatarImageView.rightAnchor, constant: margin).isActive = true
        usernameLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -margin).isActive = true
        usernameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true

        separatorView.set(height: Theme.borderHeight)
        separatorView.leftAnchor.constraint(equalTo: avatarImageView.rightAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        separatorView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }
}
