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

protocol PaymentSendControllerDelegate: class {
    func paymentSendControllerFinished(with valueInWei: NSDecimalNumber?, for controller: PaymentSendController)
}

enum PaymentSendContinueOption {
    case next
    case send
}

class PaymentSendController: PaymentController {
    
    weak var delegate: PaymentSendControllerDelegate?
    
    var continueOption: PaymentSendContinueOption
    
    var rightBarButtonItemTitle: String {
        
        switch continueOption {
        case .next:
            return Localized("payment_next_button")
        case .send:
            return Localized("payment_send_button")
        }
    }
    
    init(withContinueOption continueOption: PaymentSendContinueOption) {
        self.continueOption = continueOption
        super.init(nibName: nil, bundle: nil)
        
        title = Localized("payment_send")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemTapped(_:)))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: rightBarButtonItemTitle, style: .plain, target: self, action: #selector(continueItemTapped(_:)))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationItem.backBarButtonItem = UIBarButtonItem.back
    }

    func cancelItemTapped(_ item: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    func continueItemTapped(_ item: UIBarButtonItem) {
        delegate?.paymentSendControllerFinished(with: valueInWei, for: self)
    }
}
