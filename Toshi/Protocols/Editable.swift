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
import UIKit

protocol Editable: class {
    var scrollView: UIScrollView { get }

    func registerForKeyboardNotifications()
    func unregisterFromKeyboardNotifications()

    var keyboardWillShowSelector: Selector { get }
    var keyboardWillHideSelector: Selector { get }

    func keyboardWillShow(_ notification: NSNotification)
    func keyboardWillHide(_ notification: NSNotification)
}

extension Editable where Self: UIViewController {

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: keyboardWillShowSelector, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: keyboardWillHideSelector, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    func unregisterFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    func keyboardWillShow(_ notification: NSNotification) {
        scrollView.addBottomInsets(from: notification)
    }

    func keyboardWillHide(_ notification: NSNotification) {
        scrollView.removeBottomInsets(from: notification)
    }
}
