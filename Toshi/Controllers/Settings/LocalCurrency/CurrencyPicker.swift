import Foundation
import UIKit
import TinyConstraints

final class CurrencyPicker: UIViewController {

    fileprivate static let popularCurrenciesCodes = ["USD", "EUR", "CNY", "GBP", "CAD"]

    fileprivate var suggestedCurrencies: [Currency] = []
    fileprivate var otherCurrencies: [Currency] = []

    fileprivate lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.frame, style: .grouped)

        view.backgroundColor = UIColor.clear
        view.register(UITableViewCell.self)
        view.delegate = self
        view.dataSource = self
        view.tableFooterView = UIView()
        view.register(UITableViewCell.self)
        view.layer.borderWidth = Theme.borderHeight
        view.layer.borderColor = Theme.borderColor.cgColor

        return view
    }()

    open override func viewDidLoad() {
        super.viewDidLoad()

        title = Localized("currency_picker_title")
        view.backgroundColor = Theme.navigationBarColor
        addSubviewsAndConstraints()

        self.tableView.reloadData()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        ExchangeRateClient.getCurrencies { [weak self] results in
            guard let strongSelf = self as CurrencyPicker? else { return }

            let availableLocaleCurrencies = Locale.availableIdentifiers.flatMap { Locale(identifier: $0).currencyCode }

            strongSelf.otherCurrencies = results
                .filter { result in
                    availableLocaleCurrencies.contains(result.code) && !CurrencyPicker.popularCurrenciesCodes.contains(result.code)
                }
                .sorted { firstCurrency, secondCurrency -> Bool in
                    return  firstCurrency.code < secondCurrency.code
            }

            strongSelf.suggestedCurrencies = results
                .filter { result in
                    CurrencyPicker.popularCurrenciesCodes.contains(result.code)
                }.sorted { firstCurrency, secondCurrency -> Bool in
                    return  firstCurrency.code < secondCurrency.code
            }

            strongSelf.tableView.reloadData()
            strongSelf.tableView.scrollToRow(at: strongSelf.currentLocalCurrencyIndexPath, at: .middle, animated: false)
        }
    }

    func addSubviewsAndConstraints() {
        view.addSubview(tableView)
        tableView.edges(to: view)
    }

    fileprivate var currentLocalCurrencyIndexPath: IndexPath {
        guard let currentUser = TokenUser.current as TokenUser? else { fatalError("No current user on CurrencyListController") }

        let currentLocalCurrencyCode = currentUser.localCurrency

        if let suggestedCurrencyIndex = suggestedCurrencies.index(where: {$0.code == currentLocalCurrencyCode}) as Int? {
            return IndexPath(row: suggestedCurrencyIndex, section: 0)
        }

        let currentLocalCurrencyIndex = otherCurrencies.index(where: {$0.code == currentLocalCurrencyCode}) ?? 0
        return IndexPath(row: currentLocalCurrencyIndex, section: 1)
    }
}

extension CurrencyPicker: UITableViewDelegate {
    public func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let previousLocalCurrencyIndexPath = currentLocalCurrencyIndexPath

        let selectedCode = indexPath.section == 0 ? suggestedCurrencies[indexPath.row].code : otherCurrencies[indexPath.row].code
        TokenUser.current?.updateLocalCurrency(code: selectedCode)

        let indexPathsToReload = [previousLocalCurrencyIndexPath, indexPath]
        tableView.reloadRows(at: indexPathsToReload, with: .none)

        DispatchQueue.main.asyncAfter(seconds: 0.1) {
            self.navigationController?.popViewController(animated: true)
        }
    }
}

extension CurrencyPicker: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    public func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return suggestedCurrencies.count
        default:
            return otherCurrencies.count
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(UITableViewCell.self, for: indexPath)
        let currentCurrencyCode = TokenUser.current?.localCurrency

        let currency = indexPath.section == 0 ? suggestedCurrencies[indexPath.row] : otherCurrencies[indexPath.row]

        cell.textLabel?.text = "\(currency.name) (\(currency.code))"

        cell.accessoryType = currency.code == currentCurrencyCode ? .checkmark : .none
        cell.selectionStyle = .none

        return cell
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return suggestedCurrencies.count > 0 ? Localized("currency_picker_header_suggested") : nil
        default:
            return otherCurrencies.count > 0 ? Localized("currency_picker_header_other") : nil
        }
    }
}
