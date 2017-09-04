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

class PassphraseEnableController: UIViewController {
    
    lazy var titleLabel = TitleLabel(Localized("passphrase_enable_title"))
    lazy var textLabel = TextLabel(Localized("passphrase_enable_text"))
    
    lazy var checkboxControl: CheckboxControl = {
        let text = Localized("passphrase_enable_checkbox")

        let view = CheckboxControl(withAutoLayout: true)
        view.title = text
        view.addTarget(self, action: #selector(checked(_:)), for: .touchUpInside)

        return view
    }()

    private lazy var actionButton: ActionButton = {
        let view = ActionButton(margin: 30)
        view.title = Localized("passphrase_enable_action")
        view.isEnabled = false
        view.addTarget(self, action: #selector(proceed(_:)), for: .touchUpInside)

        return view
    }()
    
    private var isPresentedModally: Bool {
        return navigationController?.presentingViewController != nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: nil, bundle: nil)

        title = Localized("passphrase_enable_navigation_title")
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.settingsBackgroundColor

        view.addSubview(titleLabel)
        view.addSubview(textLabel)
        view.addSubview(checkboxControl)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40 + 64),
            titleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 30),
            titleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),

            textLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            textLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 30),
            textLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),

            checkboxControl.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 30),
            checkboxControl.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 30),
            checkboxControl.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),

            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isPresentedModally {
            let item = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismiss(_:)))
            navigationItem.setLeftBarButtonItems([item], animated: true)
        }
    }
    
    func dismiss(_ item: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    func checked(_ checkboxControl: CheckboxControl) {
        checkboxControl.checkbox.checked = !checkboxControl.checkbox.checked
        actionButton.isEnabled = checkboxControl.checkbox.checked
    }
    
    func proceed(_: ActionButton) {
        let controller = PassphraseCopyController()
        navigationController?.pushViewController(controller, animated: true)
    }
}
