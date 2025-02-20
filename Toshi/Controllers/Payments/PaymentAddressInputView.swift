import Foundation
import UIKit
import TinyConstraints

protocol PaymentAddressInputDelegate: class {
    func didRequestScanner()
    func didRequestSendPayment()
}

class PaymentAddressInputView: UIView {

    weak var delegate: PaymentAddressInputDelegate?

    var paymentAddress: String? {
        didSet {
            addressTextField.text = paymentAddress
        }
    }

    private lazy var topDivider: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.borderColor

        return view
    }()

    private(set) lazy var addressTextField: UITextField = {
        let view = UITextField()
        view.font = Theme.regular(size: 18)
        view.delegate = self
        view.placeholder = Localized("payment_input_placeholder")
        view.returnKeyType = .send

        return view
    }()

    private lazy var qrButton: UIButton = {
        let image = UIImage(named: "qr-icon")?.withRenderingMode(.alwaysTemplate)

        let view = UIButton()
        view.contentMode = .center
        view.tintColor = Theme.darkTextColor
        view.setImage(image, for: .normal)
        view.addTarget(self, action: #selector(qrButtonTapped(_:)), for: .touchUpInside)

        return view
    }()

    private lazy var bottomDivider: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.borderColor

        return view
    }()

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(topDivider)
        addSubview(addressTextField)
        addSubview(qrButton)
        addSubview(bottomDivider)

        topDivider.top(to: self)
        topDivider.left(to: self)
        topDivider.right(to: self)
        topDivider.height(Theme.borderHeight)

        addressTextField.left(to: self, offset: 16)
        addressTextField.centerY(to: self)

        qrButton.topToBottom(of: topDivider)
        qrButton.leftToRight(of: addressTextField)
        qrButton.bottomToTop(of: bottomDivider)
        qrButton.right(to: self)
        qrButton.width(50)
        qrButton.height(58)

        bottomDivider.left(to: self, offset: 16)
        bottomDivider.bottom(to: self)
        bottomDivider.right(to: self, offset: -16)
        bottomDivider.height(Theme.borderHeight)
    }

    func qrButtonTapped(_ button: UIButton) {
        delegate?.didRequestScanner()
    }
}

extension PaymentAddressInputView: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.didRequestSendPayment()
        return false
    }
}
