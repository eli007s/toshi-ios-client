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

class BlurView: UIVisualEffectView {

    private(set) lazy var dimmingView: UIView = {
        let dimmingView = UIView()
        dimmingView.backgroundColor = Theme.viewBackgroundColor.withAlphaComponent(0.6)

        return dimmingView
    }()

    init() {
        super.init(effect: UIBlurEffect(style: .extraLight))

        addSubviewsAndConstraints()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        effect = UIBlurEffect(style: .extraLight)
        addSubviewsAndConstraints()
    }

    private func addSubviewsAndConstraints() {
        addSubview(dimmingView)
        dimmingView.edges(to: self)
    }
}
