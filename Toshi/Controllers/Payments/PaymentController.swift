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

protocol PaymentControllerDelegate: class {
    func paymentControllerFinished(with valueInWei: NSDecimalNumber?, for controller: PaymentController)
}

enum PaymentControllerPaymentType {
    case request
    case send
    
    var title: String {
        switch self {
        case .request:
            return Localized("payment_request")
        case .send:
            return Localized("payment_send")
        }
    }
}

enum PaymentControllerContinueOption {
    case next
    case send
    
    var buttonTitle: String {
        switch self {
        case .next:
            return Localized("payment_next_button")
        case .send:
            return Localized("payment_send_button")
        }
    }
}

class PaymentController: UIViewController {
    
    weak var delegate: PaymentControllerDelegate?
    
    var paymentType: PaymentControllerPaymentType
    var continueOption: PaymentControllerContinueOption
    
    var valueInWei: NSDecimalNumber?

    lazy var currencyNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")

        return formatter
    }()
    
    lazy var inputNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        return formatter
    }()
    
    lazy var outputNumberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 2
        
        return numberFormatter
    }()

    lazy var shadowTextField: UITextField = {
        let view = UITextField(withAutoLayout: true)
        view.isHidden = true
        view.accessibilityTraits = UIAccessibilityTraitNotEnabled
        view.keyboardType = .decimalPad
        view.delegate = self

        return view
    }()

    lazy var currencyAmountLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.textAlignment = .center
        view.minimumScaleFactor = 0.25
        view.adjustsFontSizeToFitWidth = true
        view.font = Theme.regular(size: 58)
        view.text = self.currencyNumberFormatter.string(from: 0)

        return view
    }()

    lazy var etherAmountLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)
        view.textAlignment = .center
        view.minimumScaleFactor = 0.25
        view.adjustsFontSizeToFitWidth = true
        view.font = Theme.medium(size: 16)
        view.textColor = Theme.greyTextColor
        view.text = EthereumConverter.ethereumValueString(forEther: 0)

        return view
    }()

    fileprivate lazy var networkView: ActiveNetworkView = {
        self.defaultActiveNetworkView()
    }()
    
    init(withPaymentType paymentType: PaymentControllerPaymentType, continueOption: PaymentControllerContinueOption) {
        self.paymentType = paymentType
        self.continueOption = continueOption
        super.init(nibName: nil, bundle: nil)
        
        title = paymentType.title
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemTapped(_:)))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: continueOption.buttonTitle, style: .plain, target: self, action: #selector(continueItemTapped(_:)))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.viewBackgroundColor

        addSubviewsAndConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.backBarButtonItem = UIBarButtonItem.back
        shadowTextField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        shadowTextField.resignFirstResponder()
    }

    func addSubviewsAndConstraints() {
        view.addSubview(shadowTextField)
        view.addSubview(currencyAmountLabel)
        view.addSubview(etherAmountLabel)
        
        currencyAmountLabel.set(height: 64)
        currencyAmountLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 80 + 64).isActive = true
        currencyAmountLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 24).isActive = true
        currencyAmountLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -24).isActive = true

        etherAmountLabel.set(height: 34)
        etherAmountLabel.topAnchor.constraint(equalTo: currencyAmountLabel.bottomAnchor).isActive = true
        etherAmountLabel.leftAnchor.constraint(equalTo: currencyAmountLabel.leftAnchor).isActive = true
        etherAmountLabel.rightAnchor.constraint(equalTo: currencyAmountLabel.rightAnchor).isActive = true

        setupActiveNetworkView()
    }
    
    func cancelItemTapped(_ item: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    func continueItemTapped(_ item: UIBarButtonItem) {
        delegate?.paymentControllerFinished(with: valueInWei, for: self)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
}

extension PaymentController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let newValue = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) else {
            return true
        }

        guard newValue.length > 0 else {
            currencyAmountLabel.text = currencyNumberFormatter.string(from: 0)
            etherAmountLabel.text = EthereumConverter.ethereumValueString(forEther: 0)

            return true
        }

        guard let number = inputNumberFormatter.number(from: newValue) else {

            shadowTextField.text = ""

            currencyAmountLabel.text = currencyNumberFormatter.string(from: 0)
            etherAmountLabel.text = EthereumConverter.ethereumValueString(forEther: 0)

            return false
        }

        /// For NSNumber's stringValue, the decimal separator is always a `.`.
        // stringValue just calls description(withLocale:) passing nil, so it defaults to `en_US`.
        let components = newValue.components(separatedBy: inputNumberFormatter.decimalSeparator)
        if components.count == 2, let fractionalDigitsCount = components.last?.length, fractionalDigitsCount > 2 {
            return false
        }

        currencyAmountLabel.text = currencyNumberFormatter.string(from: number)

        if let currencyValue = inputNumberFormatter.number(from: newValue) {
            let ether = EthereumConverter.localFiatToEther(forFiat: currencyValue, exchangeRate: ExchangeRateClient.exchangeRate)

            if ether.isANumber {
                valueInWei = ether.multiplying(byPowerOf10: EthereumConverter.weisToEtherPowerOf10Constant)
                etherAmountLabel.text = EthereumConverter.ethereumValueString(forEther: ether)
            } else {
                etherAmountLabel.text = EthereumConverter.ethereumValueString(forEther: 0)
            }
        }

        return true
    }
}

extension PaymentController: UIToolbarDelegate {

    func position(for _: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

extension PaymentController: ActiveNetworkDisplaying {

    var activeNetworkView: ActiveNetworkView {
        return networkView
    }

    var activeNetworkViewConstraints: [NSLayoutConstraint] {
        return [activeNetworkView.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
                activeNetworkView.leftAnchor.constraint(equalTo: view.leftAnchor),
                activeNetworkView.rightAnchor.constraint(equalTo: view.rightAnchor)]
    }
}
