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

class SettingsSectionHeader: UIView {

    lazy var titleLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.textColor = Theme.sectionTitleColor
        view.font = Theme.sectionTitleFont

        return view
    }()

    lazy var errorLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.textColor = Theme.errorColor
        view.font = Theme.regular(size: 13)
        view.textAlignment = .right

        return view
    }()

    lazy var errorImage: UIImageView = {
        let view = UIImageView(withAutoLayout: true)
        view.image = #imageLiteral(resourceName: "error")
        view.setContentCompressionResistancePriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        view.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)

        return view
    }()

    convenience init(title: String, error: String? = nil) {
        self.init()
        clipsToBounds = true

        titleLabel.text = title.uppercased()
        errorLabel.text = error

        preservesSuperviewLayoutMargins = true

        addSubview(titleLabel)

        titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        if self.errorLabel.text != nil {

            addSubview(errorLabel)
            addSubview(errorImage)

            NSLayoutConstraint.activate([
                NSLayoutConstraint.constraints(withVisualFormat: "H:|-[titleLabel]", options: [], metrics: nil, views: ["titleLabel": self.titleLabel]).first!,

                self.errorLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                self.errorLabel.leftAnchor.constraint(greaterThanOrEqualTo: self.titleLabel.rightAnchor),
                self.errorLabel.rightAnchor.constraint(equalTo: self.errorImage.leftAnchor, constant: -5),

                self.errorImage.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                NSLayoutConstraint.constraints(withVisualFormat: "H:[errorImage]-|", options: [], metrics: nil, views: ["errorImage": self.errorImage]).first!
                ])
        } else {
            NSLayoutConstraint.activate([
                self.titleLabel.leftAnchor.constraint(equalTo: self.leftAnchor),
                self.titleLabel.rightAnchor.constraint(equalTo: self.rightAnchor)
                ])
        }
    }

    func setErrorHidden(_ hidden: Bool, animated: Bool) {
        errorLabel.alpha = hidden ? 0.0 : 1.0
        errorImage.alpha = hidden ? 0.0 : 1.0
    }
}
