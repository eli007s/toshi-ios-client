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

open class SettingsController: UIViewController {

    enum SettingsSection: Int {
        case profile
        case balance
        case security
        case settings

        var items: [SettingsItem] {
            switch self {
            case .profile:
                return [.profile, .qrCode]
            case .balance:
                return [.balance]
            case .security:
                return [.security]
            case .settings:
                #if DEBUG || TOSHIDEV
                    return [.localCurrency, .advanced, .signOut]
                #else
                    return [.localCurrency, .signOut]
                #endif
            }
        }

        var headerTitle: String? {
            switch self {
            case .profile:
                return Localized("settings_header_profile")
            case .balance:
                return Localized("settings_header_balance")
            case .security:
                return Localized("settings_header_security")
            case .settings:
                return Localized("settings_header_settings")
            }
        }

        var footerTitle: String? {
            switch self {
            case .settings:
                return SettingsSection.appVersionString
            default:
                return nil
            }
        }

        fileprivate static var appVersionString: String {
            let info = Bundle.main.infoDictionary!
            let version = info["CFBundleShortVersionString"]
            let buildNumber = info["CFBundleVersion"]

            return "App version: \(version ?? "").\(buildNumber ?? "")"
        }
    }

    enum SettingsItem: Int {
        case profile, qrCode, balance, security, advanced, localCurrency, signOut
    }

    fileprivate var ethereumAPIClient: EthereumAPIClient {
        return EthereumAPIClient.shared
    }

    fileprivate var chatAPIClient: ChatAPIClient {
        return ChatAPIClient.shared
    }

    fileprivate var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    private var isAccountSecured: Bool {
        return TokenUser.current?.verified ?? false
    }

    fileprivate let sections: [SettingsSection] = [.profile, .balance, .security, .settings]

    fileprivate lazy var tableView: UITableView = {

        let view = UITableView(frame: self.view.frame, style: .grouped)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.allowsSelection = true
        view.estimatedRowHeight = 64.0
        view.dataSource = self
        view.delegate = self
        view.tableFooterView = UIView()
        view.preservesSuperviewLayoutMargins = true

        view.register(UITableViewCell.self)

        return view
    }()

    fileprivate var balance: NSDecimalNumber? {
        didSet {
            self.tableView.reloadData()
        }
    }

    static func instantiateFromNib() -> SettingsController {
        guard let settingsController = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController() as? SettingsController else { fatalError("Storyboard named 'Settings' should be provided in application") }

        return  settingsController
    }

    private override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        title = Localized("settings_navigation_title")

        view.addSubview(tableView)
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.backgroundColor = Theme.settingsBackgroundColor

        tableView.registerNib(SettingsProfileCell.self)
        tableView.registerNib(InputCell.self)

        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .currentUserUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleBalanceUpdate(notification:)), name: .ethereumBalanceUpdateNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleUpdateLocalCurrency), name: .localCurrencyUpdated, object: nil)

        self.fetchAndUpdateBalance()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        IDAPIClient.shared.updateContact(with: Cereal.shared.address)
    }

    @objc private func updateUI() {
        self.tableView.reloadData()
    }

    @objc private func handleUpdateLocalCurrency() {
        self.balance = self.balance ?? .zero
    }

    @objc private func handleBalanceUpdate(notification: Notification) {
        guard notification.name == .ethereumBalanceUpdateNotification, let balance = notification.object as? NSDecimalNumber else { return }
        self.balance = balance
    }

    fileprivate func fetchAndUpdateBalance() {
        self.ethereumAPIClient.getBalance(address: Cereal.shared.paymentAddress) { [weak self] balance, error in
            if let error = error {
                let alertController = UIAlertController.errorAlert(error as NSError)
                Navigator.presentModally(alertController)
            } else {
                self?.balance = balance
            }
        }
    }

    fileprivate func handleSignOut() {
        guard let currentUser = TokenUser.current else {
            let alert = UIAlertController(title: Localized("settings_signout_error_title"), message: Localized("settings_signout_error_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("settings_signout_action_ok"), style: .default, handler: { _ in
                fatalError()
            }))
            Navigator.presentModally(alert)

            return
        }

        let alert = self.alertController(balance: currentUser.balance)
        // We dispatch it back to the main thread here, even tho we are already inside the main thread
        // to avoid some weird issue where the alert controller will take seconds to present, instead of being instant.
        DispatchQueue.main.async {
            Navigator.presentModally(alert)
        }
    }

    func alertController(balance: NSDecimalNumber) -> UIAlertController {
        var alert: UIAlertController

        if self.isAccountSecured {
            alert = UIAlertController(title: Localized("settings_signout_insecure_title"), message: Localized("settings_signout_insecure_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("settings_signout_action_cancel"), style: .cancel))

            alert.addAction(UIAlertAction(title: Localized("settings_signout_action_signout"), style: .destructive) { _ in
                (UIApplication.shared.delegate as? AppDelegate)?.signOutUser()
            })
        } else if balance == .zero {
            alert = UIAlertController(title: Localized("settings_signout_nofunds_title"), message: Localized("settings_signout_nofunds_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("settings_signout_action_cancel"), style: .cancel))

            alert.addAction(UIAlertAction(title: Localized("settings_signout_action_delete"), style: .destructive) { _ in
                (UIApplication.shared.delegate as? AppDelegate)?.signOutUser()
            })
        } else {
            alert = UIAlertController(title: Localized("settings_signout_stepsneeded_title"), message: Localized("settings_signout_stepsneeded_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("settings_signout_action_ok"), style: .cancel))
        }

        alert.view.tintColor = Theme.tintColor

        return alert
    }

    fileprivate func setupProfileCell(_ cell: UITableViewCell) {
        guard let cell = cell as? SettingsProfileCell else { return }

        cell.displayNameLabel.text = TokenUser.current?.name
        cell.usernameLabel.text = TokenUser.current?.displayUsername

        guard let avatarPath = TokenUser.current?.avatarPath as String? else { return }
        AvatarManager.shared.avatar(for: avatarPath) { image, _ in
            cell.avatarImageView.image = image
        }
    }

    fileprivate func pushViewController(_ storyboardName: String) {
        guard let storyboard = UIStoryboard(name: storyboardName, bundle: nil) as UIStoryboard? else { return }
        guard let controller = storyboard.instantiateInitialViewController() else { return }

        self.navigationController?.pushViewController(controller, animated: true)
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 2 {
            let view = SettingsSectionHeader(title: Localized("settings_header_security"), error: Localized("settings_header_security_text"))
            view.setErrorHidden(self.isAccountSecured, animated: false)

            return view
        }

        return nil
    }
}

extension SettingsController: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var cell: UITableViewCell

        let section = sections[indexPath.section]
        let item = section.items[indexPath.row]

        switch item {
        case .profile:
            cell = tableView.dequeue(SettingsProfileCell.self, for: indexPath)
        case .balance:
            cell = tableView.dequeue(InputCell.self, for: indexPath)
        default:
            cell = tableView.dequeue(UITableViewCell.self, for: indexPath)
        }

        switch item {
        case .profile:
            setupProfileCell(cell)
        case .qrCode:
            cell.textLabel?.text = Localized("settings_cell_qr")
            cell.textLabel?.textColor = Theme.darkTextColor
            cell.accessoryType = .disclosureIndicator
        case .balance:
            if let cell = cell as? InputCell {

                let balance = self.balance ?? .zero

                let ethereumValueString = EthereumConverter.ethereumValueString(forWei: balance)
                let fiatValueString = EthereumConverter.fiatValueStringWithCode(forWei: balance, exchangeRate: ExchangeRateClient.exchangeRate)

                cell.titleLabel.text = fiatValueString
                cell.textField.text = ethereumValueString
                cell.textField.textAlignment = .right
                cell.textField.isUserInteractionEnabled = false
                cell.switchControl.isHidden = true

                cell.titleWidthConstraint?.isActive = false
                cell.titleLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
                
                cell.accessoryType = .disclosureIndicator
            }
        case .security:
            cell.textLabel?.text = Localized("settings_cell_passphrase")
            cell.textLabel?.textColor = Theme.darkTextColor
            cell.accessoryType = .disclosureIndicator
        case .localCurrency:
            cell.textLabel?.text = Localized("Local currency")
            cell.textLabel?.textColor = Theme.darkTextColor
            cell.accessoryType = .disclosureIndicator
        case .advanced:
            cell.textLabel?.text = Localized("settings_cell_advanced")
            cell.textLabel?.textColor = Theme.darkTextColor
            cell.accessoryType = .disclosureIndicator
        case .signOut:
            cell.textLabel?.text = Localized("settings_cell_signout")
            cell.textLabel?.textColor = Theme.errorColor
            cell.accessoryType = .none
        }

        return cell
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    public func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = sections[section]
        return sectionInfo.items.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = sections[indexPath.section]
        let item = section.items[indexPath.row]

        switch item {
        case .profile:
            return UITableViewAutomaticDimension
        default:
            return 44.0
        }
    }
}

extension SettingsController: UITableViewDelegate {

    public func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let sectionInfo = sections[indexPath.section]
        let item = sectionInfo.items[indexPath.row]

        switch item {
        case .profile:
            self.navigationController?.pushViewController(ProfileController(), animated: true)
        case .qrCode:
            guard let current = TokenUser.current else { return }
            let qrCodeController = QRCodeController(for: current.displayUsername, name: current.name)

            self.navigationController?.pushViewController(qrCodeController, animated: true)
        case .balance:
            let controller = BalanceController()
            if let balance = balance {
                controller.balance = balance
            }
            self.navigationController?.pushViewController(controller, animated: true)
        case .security:
            self.navigationController?.pushViewController(PassphraseEnableController(), animated: true)
        case .localCurrency:
            self.navigationController?.pushViewController(CurrencyPicker(), animated: true)
        case .advanced:
            self.pushViewController("AdvancedSettings")
        case .signOut:
            self.handleSignOut()
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionInfo = sections[section]
        return sectionInfo.headerTitle
    }

    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let sectionInfo = sections[section]
        return sectionInfo.footerTitle
    }
}
