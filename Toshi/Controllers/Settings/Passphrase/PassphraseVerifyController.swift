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

class PassphraseVerifyController: UIViewController {

    fileprivate var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    private let navigationBarCompensation: CGFloat = 64
    private let margin: CGFloat = 30

    lazy var titleLabel: TitleLabel = {
        let view = TitleLabel(Localized("passphrase_verify_title"))

        return view
    }()

    lazy var textLabel: UILabel = {
        let view = TextLabel(Localized("passphrase_verify_text"))
        view.textAlignment = .center

        return view
    }()

    fileprivate lazy var shuffledPassphraseView: PassphraseView = {
        let view = PassphraseView(with: Cereal().mnemonic.words, for: .shuffled)
        view.addDelegate = self

        return view
    }()

    fileprivate lazy var verifyPassphraseView: PassphraseView = {
        let view = PassphraseView(with: Cereal().mnemonic.words, for: .verification)
        view.removeDelegate = self
        view.verificationDelegate = self
        view.backgroundColor = Theme.passphraseVerificationContainerColor

        return view
    }()

    fileprivate lazy var guides: [UILayoutGuide] = {
        [UILayoutGuide(), UILayoutGuide(), UILayoutGuide(), UILayoutGuide(), UILayoutGuide()]
    }()

    public required init?(coder _: NSCoder) {
        fatalError("")
    }

    public init() {
        super.init(nibName: nil, bundle: nil)

        title = Localized("passphrase_verify_navigation_title")
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.settingsBackgroundColor

        addSubviewsAndConstraints()
    }

    func addSubviewsAndConstraints() {
        view.addSubview(titleLabel)
        view.addSubview(textLabel)
        view.addSubview(verifyPassphraseView)
        view.addSubview(shuffledPassphraseView)

        /*
         Between each view we place a layout-guide to add dynamic control of
         the spacing between the views. We do this by setting a target height
         for the first layout-guide and chain the height constraints of all
         layout-guides to each other.
         This way the spacing between each view remains equal to each other,
         even when the target height for the first layout-guide is not reached.
         */

        for guide in guides {
            view.addLayoutGuide(guide)
        }

        NSLayoutConstraint.activate([
            self.guides[0].topAnchor.constraint(equalTo: self.view.topAnchor, constant: self.navigationBarCompensation),
            self.guides[0].leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.guides[0].bottomAnchor.constraint(equalTo: self.titleLabel.topAnchor),
            self.guides[0].rightAnchor.constraint(equalTo: self.view.rightAnchor),

            self.titleLabel.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: self.margin),
            self.titleLabel.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -self.margin),

            self.guides[1].topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
            self.guides[1].leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.guides[1].bottomAnchor.constraint(equalTo: self.textLabel.topAnchor),
            self.guides[1].rightAnchor.constraint(equalTo: self.view.rightAnchor),

            self.textLabel.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: self.margin),
            self.textLabel.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -self.margin),

            self.guides[2].topAnchor.constraint(equalTo: self.textLabel.bottomAnchor),
            self.guides[2].leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.guides[2].bottomAnchor.constraint(equalTo: self.verifyPassphraseView.topAnchor),
            self.guides[2].rightAnchor.constraint(equalTo: self.view.rightAnchor),

            self.verifyPassphraseView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: self.margin / 2),
            self.verifyPassphraseView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -self.margin / 2),

            self.guides[3].topAnchor.constraint(equalTo: self.verifyPassphraseView.bottomAnchor),
            self.guides[3].leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.guides[3].bottomAnchor.constraint(equalTo: self.shuffledPassphraseView.topAnchor),
            self.guides[3].rightAnchor.constraint(equalTo: self.view.rightAnchor),

            self.shuffledPassphraseView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: self.margin / 2),
            self.shuffledPassphraseView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -self.margin / 2),
            self.shuffledPassphraseView.heightAnchor.constraint(equalTo: self.verifyPassphraseView.heightAnchor).priority(.high),

            self.guides[4].topAnchor.constraint(equalTo: self.shuffledPassphraseView.bottomAnchor),
            self.guides[4].leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.guides[4].bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.guides[4].rightAnchor.constraint(equalTo: self.view.rightAnchor),

            self.guides[0].heightAnchor.constraint(equalToConstant: self.margin).priority(.high),
            self.guides[1].heightAnchor.constraint(equalTo: self.guides[0].heightAnchor, multiplier: 0.5),
            self.guides[2].heightAnchor.constraint(equalTo: self.guides[0].heightAnchor),
            self.guides[3].heightAnchor.constraint(equalTo: self.guides[2].heightAnchor),
            self.guides[4].heightAnchor.constraint(equalTo: self.guides[3].heightAnchor)
        ])
    }
}

extension PassphraseVerifyController: AddDelegate {

    func add(_ wordView: PassphraseWordView) {
        guard let word = wordView.word else { return }

        verifyPassphraseView.add(word)
        wordView.isEnabled = false
    }
}

extension PassphraseVerifyController: RemoveDelegate {

    func remove(_ wordView: PassphraseWordView) {
        guard let word = wordView.word else { return }

        verifyPassphraseView.remove(word)
        shuffledPassphraseView.reset(word)
    }
}

extension PassphraseVerifyController: VerificationDelegate {

    func verify(_ phrase: Phrase) -> VerificationStatus {
        assert(Cereal().mnemonic.words.count <= 12, "Too large")

        let originalPhrase = Cereal().mnemonic.words

        guard originalPhrase.count == phrase.count else {
            return .tooShort
        }

        if originalPhrase == phrase.map { word in word.text } {
            DispatchQueue.main.asyncAfter(seconds: 0.5) {
                guard let rootViewController = self.navigationController?.viewControllers.first else { return }
                
                if rootViewController is SettingsController {
                    _ = self.navigationController?.popToRootViewController(animated: true)
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            }

            return .correct
        }

        return .incorrect
    }
}
