import Foundation
import UIKit
import TinyConstraints
import CameraScanner

class PaymentAddressController: UIViewController {
    
    fileprivate let valueInWei: NSDecimalNumber
    
    private lazy var valueLabel: UILabel = {
        let value = EthereumConverter.fiatValueString(forWei: self.valueInWei, exchangeRate: EthereumAPIClient.shared.exchangeRate)
        
        let view = UILabel()
        view.font = Theme.regular(size: 34)
        view.textAlignment = .center
        view.adjustsFontSizeToFitWidth = true
        view.minimumScaleFactor = 0.5
        view.text = Localized("payment_send_prefix") + "\(value)"
        
        return view
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.regular(size: 17)
        view.textAlignment = .center
        view.numberOfLines = 0
        view.text = Localized("payment_send_description")
        
        return view
    }()
    
    fileprivate lazy var addressInputView: PaymentAddressInputView = {
        let view = PaymentAddressInputView()
        view.delegate = self
        
        return view
    }()
    
    private lazy var sendBarButton = UIBarButtonItem(title: Localized("payment_send_button"), style: .plain, target: self, action: #selector(sendBarButtonTapped(_:)))
    
    init(with valueInWei: NSDecimalNumber) {
        self.valueInWei = valueInWei
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Theme.viewBackgroundColor
        
        view.addSubview(valueLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(addressInputView)
        
        valueLabel.top(to: view, offset: 67)
        valueLabel.left(to: view, offset: 16)
        valueLabel.right(to: view, offset: -16)
        
        descriptionLabel.topToBottom(of: valueLabel, offset: 10)
        descriptionLabel.left(to: view, offset: 16)
        descriptionLabel.right(to: view, offset: -16)
        
        addressInputView.topToBottom(of: descriptionLabel, offset: 40)
        addressInputView.left(to: view)
        addressInputView.right(to: view)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationItem.backBarButtonItem = UIBarButtonItem.back
        navigationItem.rightBarButtonItem = sendBarButton
        
        addressInputView.addressTextField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        addressInputView.addressTextField.resignFirstResponder()
    }
    
    func sendBarButtonTapped(_ item: UIBarButtonItem) {
        sendPayment()
    }
    
    func sendPayment() {
        guard let paymentAddress = addressInputView.addressTextField.text else { return }
        
        Payment.send(valueInWei, to: paymentAddress) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
    }
}

extension PaymentAddressController: PaymentAddressInputDelegate {
    
    func didRequestScanner() {
        let scannerController = ScannerController(instructions: Localized("payment_qr_scanner_instructions"), types: [.qrCode])
        scannerController.delegate = self
        Navigator.presentModally(scannerController)
    }
    
    func didRequestSendPayment() {
        sendPayment()
    }
}

extension PaymentAddressController: ScannerViewControllerDelegate {
    
    public func scannerViewControllerDidCancel(_ controller: ScannerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    public func scannerViewController(_ controller: ScannerViewController, didScanResult result: String) {
        
        if let intent = QRCodeIntent(result: result), case .addContact(let username) = intent {
            let name = TokenUser.name(from: username)
            
            IDAPIClient.shared.retrieveContact(username: name) { [weak self] contact in
                guard let contact = contact else {
                    controller.startScanning()
                    
                    return
                }
                
                self?.addressInputView.paymentAddress = contact.paymentAddress
                
                SoundPlayer.playSound(type: .scanned)
                controller.dismiss(animated: true, completion: nil)
            }
        }
    }
}
