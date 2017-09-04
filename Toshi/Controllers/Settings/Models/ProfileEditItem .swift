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

import Foundation

enum InputType: Int {
    case text, state
}

enum ProfileEditItemType: Int {
    case none, username, displayName, about, location, visibility

    var autocapitalizationType: UITextAutocapitalizationType {
        switch self {
        case .username:
            return .none
        default:
            return .words
        }
    }
}

public struct ProfileEditSection {
    var items = [ProfileEditItem]()
    var headerTitle: String?
    var footerTitle: String?

    init(items: [ProfileEditItem], headerTitle: String? = nil, footerTitle: String? = nil) {
        self.items = items
        self.headerTitle = headerTitle
        self.footerTitle = footerTitle
    }
}

public class ProfileEditItem {

    private(set) var type: ProfileEditItemType = .none

    private(set) var titleText = ""
    private(set) var detailText = ""
    private(set) var switchMode = false

    init(_ type: ProfileEditItemType) {
        self.type = type

        guard let user = TokenUser.current as TokenUser? else { return }

        switch type {
        case .username:
            titleText = Localized("Username")
            detailText = user.username
        case .displayName:
            titleText = Localized("Display name")
            detailText = user.name
        case .about:
            titleText = Localized("About")
            detailText = user.about
        case .location:
            titleText = Localized("Location")
            detailText = user.location
        case .visibility:
            titleText = Localized("Public")
            switchMode = user.isPublic
        default:
            break
        }
    }

    func update(_ detailText: String?, _ switchMode: Bool) {
        self.detailText = detailText ?? ""
        self.switchMode = switchMode
    }
}
