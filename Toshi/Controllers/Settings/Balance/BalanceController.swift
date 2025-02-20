import Foundation
import UIKit
import TinyConstraints

class BalanceController: UIViewController {

    var balance: NSDecimalNumber? {
        didSet {
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
        }
    }

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = nil
        view.dataSource = self
        view.delegate = self
        view.separatorStyle = .singleLine

        view.register(UITableViewCell.self, forCellReuseIdentifier: self.reuseIdentifier)
        view.registerNib(InputCell.self)

        return view
    }()

    fileprivate let reuseIdentifier = "BalanceControllerCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.settingsBackgroundColor

        title = Localized("balance-navigation-title")

        view.addSubview(tableView)
        tableView.edges(to: view)

        NotificationCenter.default.addObserver(self, selector: #selector(handleBalanceUpdate(notification:)), name: .ethereumBalanceUpdateNotification, object: nil)
        fetchAndUpdateBalance()
    }

    @objc private func handleBalanceUpdate(notification: Notification) {
        guard notification.name == .ethereumBalanceUpdateNotification, let balance = notification.object as? NSDecimalNumber else { return }
        self.balance = balance
    }

    fileprivate func fetchAndUpdateBalance() {

        EthereumAPIClient.shared.getBalance(address: Cereal.shared.paymentAddress) { [weak self] balance, error in
            if let error = error {
                Navigator.presentModally(UIAlertController.errorAlert(error as NSError))
            } else {
                self?.balance = balance
            }
        }
    }
}

extension BalanceController: UITableViewDelegate {

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.row == 1 {
            
            let paymentController = PaymentController(withPaymentType: .send, continueOption: .next)
            paymentController.delegate = self
            
            let navigationController = PaymentNavigationController(rootViewController: paymentController)
            Navigator.presentModally(navigationController)
            
        } else if indexPath.row == 2 {
            guard let current = TokenUser.current else { return }
            let controller = AddMoneyController(for: current.displayUsername, name: current.name)
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
}

extension BalanceController: UITableViewDataSource {

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.selectionStyle = .none

        switch indexPath.row {
        case 0:
            if let balance = balance {
               let cell = tableView.dequeue(InputCell.self, for: indexPath)
                cell.selectionStyle = .none

                let ethereumValueString = EthereumConverter.ethereumValueString(forWei: balance)
                let fiatValueString = EthereumConverter.fiatValueStringWithCode(forWei: balance, exchangeRate: ExchangeRateClient.exchangeRate)

                cell.titleLabel.text = fiatValueString
                cell.textField.text = ethereumValueString
                cell.textField.textAlignment = .right
                cell.textField.isUserInteractionEnabled = false
                cell.switchControl.isHidden = true

                cell.titleWidthConstraint?.isActive = false
                cell.titleLabel.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
            }
        case 1:
            cell.textLabel?.text = Localized("balance-action-send")
            cell.textLabel?.textColor = Theme.tintColor
            cell.textLabel?.font = Theme.regular(size: 17)
        case 2:
            cell.textLabel?.text = Localized("balance-action-deposit")
            cell.textLabel?.textColor = Theme.tintColor
            cell.textLabel?.font = Theme.regular(size: 17)
        default:
            break
        }

        return cell
    }
}

extension BalanceController: PaymentControllerDelegate {
    
    func paymentControllerFinished(with valueInWei: NSDecimalNumber?, for controller: PaymentController) {
        guard let valueInWei = valueInWei else { return }
        
        let paymentAddressController = PaymentAddressController(with: valueInWei)
        controller.navigationController?.pushViewController(paymentAddressController, animated: true)
    }
}
