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
import SweetSwift
import SweetFoundation

/// ChatsTableController cells.
class ChatCell: UITableViewCell {
    var thread: TSThread? {
        didSet {
            // last visible message
            if let message = self.thread?.messages.last, let messageBody = message.body {

                switch SofaType(sofa: messageBody) {
                case .message:
                    lastMessageLabel.attributedText = NSMutableAttributedString(string: SofaMessage(content: messageBody).body, attributes: messageAttributes)
                case .paymentRequest:
                    lastMessageLabel.attributedText = NSMutableAttributedString(string: SofaPaymentRequest(content: messageBody).body, attributes: messageAttributes)
                default:
                    lastMessageLabel.attributedText = nil
                }
            } else {
                lastMessageLabel.attributedText = nil
            }

            // date
            if let date = self.thread?.lastMessageDate() {
                if DateTimeFormatter.isDate(date, sameDayAs: Date()) {
                    lastMessageDateLabel.text = DateTimeFormatter.timeFormatter.string(from: date)
                } else {
                    lastMessageDateLabel.text = DateTimeFormatter.dateFormatter.string(from: date)
                }
            }

            // unread badge
            if let thread = self.thread {
                let unreadMessagesCount = TSMessagesManager.shared().unreadMessages(in: thread)
                if unreadMessagesCount > 0 {
                    unreadLabel.text = "\(unreadMessagesCount)"
                    unreadView.isHidden = false
                    lastMessageDateLabel.textColor = Theme.tintColor
                } else {
                    unreadLabel.text = nil
                    unreadView.isHidden = true
                    lastMessageDateLabel.textColor = Theme.greyTextColor
                }
            }

            guard let delegate = UIApplication.shared.delegate as? AppDelegate else { return }
            if let contact = delegate.contactsManager.tokenContact(forAddress: self.thread?.contactIdentifier() ?? "") {
                updateContact(contact)
            } else {
                IDAPIClient.shared.retrieveContact(username: thread?.contactIdentifier() ?? "") { contact in
                    guard let contact = contact else { return }
                    self.updateContact(contact)
                }
            }

            if let lastMessage = self.lastMessageLabel.text, !lastMessage.isEmpty {
                textGuideHeight.constant = 5
            } else {
                textGuideHeight.constant = 0
            }
        }
    }

    lazy var messageAttributes: [String: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2.5
        paragraphStyle.paragraphSpacing = -4
        paragraphStyle.lineBreakMode = .byTruncatingTail

        return [
            NSFontAttributeName: Theme.regular(size: 15),
            NSForegroundColorAttributeName: Theme.greyTextColor,
            NSParagraphStyleAttributeName: paragraphStyle
        ]
    }()

    // Container that contains the unread label and
    // provides a colored background with content insets.
    lazy var unreadView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.tintColor
        view.layer.cornerRadius = 12
        view.clipsToBounds = true

        self.unreadLabel.font = Theme.regular(size: 15)
        self.unreadLabel.textColor = Theme.lightTextColor
        self.unreadLabel.textAlignment = .center
        view.addSubview(self.unreadLabel)

        self.unreadLabel.edges(to: view, insets: UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5))

        return view
    }()

    lazy var unreadLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.semibold(size: 15)
        view.textColor = Theme.lightTextColor
        view.textAlignment = .center

        return view
    }()

    lazy var avatarImageView: AvatarImageView = {
        let view = AvatarImageView()

        return view
    }()

    lazy var usernameLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.semibold(size: 16)
        view.textColor = Theme.darkTextColor

        return view
    }()

    lazy var lastMessageLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2

        return view
    }()

    lazy var lastMessageDateLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.regular(size: 15)
        view.textAlignment = .right
        view.textColor = Theme.tintColor

        return view
    }()

    lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.borderColor

        return view
    }()

    lazy var guides: [UILayoutGuide] = {
        [UILayoutGuide(), UILayoutGuide(), UILayoutGuide()]
    }()

    lazy var textGuide: UILayoutGuide = {
        UILayoutGuide()
    }()

    lazy var textGuideHeight: NSLayoutConstraint = {
        self.textGuide.height(0)
    }()

    override func prepareForReuse() {
        super.prepareForReuse()

        unreadLabel.text = nil
        avatarImageView.image = nil
        usernameLabel.text = nil
        lastMessageLabel.text = nil
        lastMessageDateLabel.text = nil
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        accessoryType = .disclosureIndicator

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = Theme.cellSelectionColor
        self.selectedBackgroundView = selectedBackgroundView

        contentView.addSubview(unreadView)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(lastMessageLabel)
        contentView.addSubview(lastMessageDateLabel)
        contentView.addSubview(separatorView)

        for guide in guides {
            contentView.addLayoutGuide(guide)
        }

        contentView.addLayoutGuide(textGuide)

        let margin: CGFloat = 15.0

        guides[0].left(to: contentView, offset: margin)
        guides[0].centerY(to: contentView)

        guides[1].leftToRight(of: guides[0], offset: margin)
        guides[1].centerY(to: contentView)

        guides[2].top(to: guides[1])
        guides[2].leftToRight(of: guides[1], offset: margin)
        guides[2].right(to: contentView, offset: 0)

        avatarImageView.size(CGSize(width: 44, height: 44))
        avatarImageView.centerY(to: guides[0])
        avatarImageView.left(to: guides[0])
        avatarImageView.right(to: guides[0])

        usernameLabel.top(to: guides[1])
        usernameLabel.left(to: guides[1])
        usernameLabel.right(to: guides[1])

        textGuide.topToBottom(of: usernameLabel)
        textGuide.left(to: guides[1])
        textGuide.right(to: guides[1])

        lastMessageLabel.topToBottom(of: textGuide)
        lastMessageLabel.left(to: guides[1])
        lastMessageLabel.right(to: guides[1])
        lastMessageLabel.bottom(to: guides[1])

        lastMessageDateLabel.top(to: contentView, offset: 10)
        lastMessageDateLabel.left(to: guides[2])
        lastMessageDateLabel.right(to: guides[2])

        unreadView.topToBottom(of: lastMessageDateLabel, offset: 12)
        unreadView.right(to: guides[2])
        unreadView.height(24)
        unreadView.width(24, relation: .equalOrGreater)

        separatorView.left(to: guides[1])
        separatorView.right(to: self)
        separatorView.height(Theme.borderHeight)
        separatorView.bottom(to: contentView)
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }

    func updateContact(_ contact: TokenUser) {
        usernameLabel.text = !contact.name.isEmpty ? contact.name : contact.displayUsername

        AvatarManager.shared.avatar(for: contact.avatarPath) { [weak self] image, path in
            if contact.avatarPath == path {
                self?.avatarImageView.image = image
            }
        }
    }
}
