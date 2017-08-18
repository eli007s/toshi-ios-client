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
import SweetFoundation
import ImagePicker

/// Edit user profile info. It's sent to the ID server on saveAndDismiss. Updates local session as well.
open class ProfileEditController: OverlayController, Editable {

    fileprivate static let profileVisibilitySectionTitle = Localized("Profile visibility")
    fileprivate static let profileVisibilitySectionFooter = Localized("Setting your profile to public will allow it to show up on the Browse page. Other users will be able to message you from there.")

    var scrollView: UIScrollView {
        return tableView
    }

    var keyboardWillShowSelector: Selector {
        return #selector(keyboardShownNotificationReceived(_:))
    }

    var keyboardWillHideSelector: Selector {
        return #selector(keyboardShownNotificationReceived(_:))
    }

    @objc private func keyboardShownNotificationReceived(_ notification: NSNotification) {
        keyboardWillShow(notification)
    }

    @objc private func keyboardHiddenNotificationReceived(_ notification: NSNotification) {
        keyboardWillHide(notification)
    }

    fileprivate var menuSheetController: MenuSheetController?

    fileprivate let editingSections = [ProfileEditSection(items: [ProfileEditItem(.username), ProfileEditItem(.displayName), ProfileEditItem(.about), ProfileEditItem(.location)]),
                                       ProfileEditSection(items: [ProfileEditItem(.visibility)], headerTitle: profileVisibilitySectionTitle, footerTitle: profileVisibilitySectionFooter)]

    fileprivate var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    fileprivate lazy var avatarImageView: AvatarImageView = {
        let view = AvatarImageView(withAutoLayout: true)

        return view
    }()

    fileprivate lazy var changeAvatarButton: UIButton = {
        let view = UIButton(withAutoLayout: true)

        let title = NSAttributedString(string: Localized("Change profile photo"), attributes: [NSForegroundColorAttributeName: Theme.tintColor, NSFontAttributeName: Theme.regular(size: 16)])
        view.setAttributedTitle(title, for: .normal)
        view.addTarget(self, action: #selector(updateAvatar), for: .touchUpInside)

        return view
    }()

    fileprivate lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.frame, style: .grouped)
        view.translatesAutoresizingMaskIntoConstraints = false

        let tabBarHeight: CGFloat = 49.0
        view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: tabBarHeight, right: 0.0)
        view.backgroundColor = UIColor.clear
        view.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: tabBarHeight, right: 0.0)
        view.register(InputCell.self)
        view.delegate = self
        view.dataSource = self
        view.tableFooterView = UIView()
        view.register(UINib(nibName: "InputCell", bundle: nil), forCellReuseIdentifier: String(describing: InputCell.self))
        view.layer.borderWidth = Theme.borderHeight
        view.layer.borderColor = Theme.borderColor.cgColor
        view.alwaysBounceVertical = true

        return view
    }()

    open override var canBecomeFirstResponder: Bool {
        return true
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        title = Localized("Edit profile")
        view.backgroundColor = Theme.navigationBarColor
        self.addSubviewsAndConstraints()

        guard let user = TokenUser.current else { return }

        if let path = user.avatarPath as String? {
            AvatarManager.shared.avatar(for: path) { [weak self] image, _ in
                self?.avatarImageView.image = image
            }
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.didTapView))
        view.addGestureRecognizer(tapGesture)

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelAndDismiss))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.saveAndDismiss))
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([NSFontAttributeName: Theme.bold(size: 17.0),
                                                                   NSForegroundColorAttributeName: Theme.tintColor], for: .normal)
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerForKeyboardNotifications()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        unregisterFromKeyboardNotifications()
    }

    fileprivate lazy var headerView: UIView = {
        let view = UIView(frame: CGRect.zero)

        view.backgroundColor = UIColor.clear
        view.addSubview(self.avatarImageView)
        view.addSubview(self.changeAvatarButton)

        let bottomBorder = UIView(withAutoLayout: true)
        view.addSubview(bottomBorder)

        bottomBorder.backgroundColor = Theme.borderColor
        bottomBorder.set(height: Theme.borderHeight)
        bottomBorder.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        bottomBorder.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        self.avatarImageView.set(height: 80)
        self.avatarImageView.set(width: 80)
        self.avatarImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 24).isActive = true
        self.avatarImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true

        self.changeAvatarButton.set(height: 38)
        self.changeAvatarButton.topAnchor.constraint(equalTo: self.avatarImageView.bottomAnchor, constant: 12).isActive = true
        self.changeAvatarButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24).isActive = true
        self.changeAvatarButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true

        view.layoutIfNeeded()

        return view
    }()

    func addSubviewsAndConstraints() {
        let height = headerView.systemLayoutSizeFitting(UILayoutFittingExpandedSize).height

        var headerFrame = headerView.frame
        headerFrame.size.height = height
        headerView.frame = headerFrame

        tableView.tableHeaderView = headerView

        view.addSubview(tableView)

        view.addSubview(self.activityIndicator)

        self.activityIndicator.set(height: 50.0)
        self.activityIndicator.set(width: 50.0)
        self.activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        self.activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        tableView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    func updateAvatar() {
        menuSheetController = MenuSheetController()
        menuSheetController?.dismissesByOutsideTap = true
        menuSheetController?.hasSwipeGesture = true
        menuSheetController?.maxHeight = 445 - MenuSheetButtonItemViewHeight
        var itemViews = [UIView]()

        let carouselItem = AttachmentCarouselItemView(camera: Camera.cameraAvailable(), selfPortrait: false, forProfilePhoto: true, assetType: MediaAssetPhotoType)!
        carouselItem.condensed = false
        carouselItem.openEditor = true
        carouselItem.parentController = self
        carouselItem.allowCaptions = true
        carouselItem.inhibitDocumentCaptions = true
        carouselItem.suggestionContext = SuggestionContext()
        carouselItem.cameraPressed = { cameraView in
            guard AccessChecker.checkCameraAuthorizationStatus(alertDismissComlpetion: nil) == true else { return }

            self.displayCamera(from: cameraView, menu: self.menuSheetController!, carouselItem: carouselItem)
        }

        carouselItem.avatarCompletionBlock = { image in
            self.menuSheetController?.dismiss(animated: true, manual: false) {
                self.changeAvatar(to: image)
            }
        }

        itemViews.append(carouselItem)

        let galleryItem = MenuSheetButtonItemView(title: "Library", type: MenuSheetButtonTypeDefault, action: {
            self.menuSheetController?.dismiss(animated: true)
            self.displayMediaPicker(forFile: false, fromFileMenu: false)
        })!

        itemViews.append(galleryItem)

        carouselItem.underlyingViews = [galleryItem]

        let cancelItem = MenuSheetButtonItemView(title: "Cancel", type: MenuSheetButtonTypeCancel, action: {
            self.menuSheetController?.dismiss(animated: true)
        })!

        itemViews.append(cancelItem)
        menuSheetController?.setItemViews(itemViews)
        carouselItem.remainingHeight = MenuSheetButtonItemViewHeight * CGFloat(itemViews.count - 1)

        menuSheetController?.present(in: self, sourceView: view, animated: true)
    }

    private func displayMediaPicker(forFile _: Bool, fromFileMenu _: Bool) {

        guard AccessChecker.checkPhotoAuthorizationStatus(intent: PhotoAccessIntentRead, alertDismissCompletion: nil) else { return }
        let dismissBlock = { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }

        let showMediaPickerBlock: ((MediaAssetGroup?) -> Void) = { [unowned self] group in
            let intent: MediaAssetsControllerIntent = .setProfilePhoto // forFile ? MediaAssetsControllerIntentSendMedia : MediaAssetsControllerIntentSendMedia
            let assetsController = MediaAssetsController(assetGroup: group, intent: intent)!
            assetsController.captionsEnabled = true
            assetsController.inhibitDocumentCaptions = true
            assetsController.suggestionContext = SuggestionContext()
            assetsController.dismissalBlock = dismissBlock
            assetsController.localMediaCacheEnabled = false
            assetsController.shouldStoreAssets = false
            assetsController.shouldShowFileTipIfNeeded = false

            assetsController.avatarCompletionBlock = { image in
                assetsController.dismiss(animated: true, completion: nil)
                self.changeAvatar(to: image)
            }

            Navigator.presentModally(assetsController)
        }

        if MediaAssetsLibrary.authorizationStatus() == MediaLibraryAuthorizationStatusNotDetermined {
            MediaAssetsLibrary.requestAuthorization(for: MediaAssetAnyType) { (_, cameraRollGroup) -> Void in

                let photoAllowed = AccessChecker.checkPhotoAuthorizationStatus(intent: PhotoAccessIntentRead, alertDismissCompletion: nil)
                let microphoneAllowed = AccessChecker.checkMicrophoneAuthorizationStatus(for: MicrophoneAccessIntentVideo, alertDismissCompletion: nil)

                if photoAllowed == false || microphoneAllowed == false {
                    return
                }

                showMediaPickerBlock(cameraRollGroup)
            }
        }

        showMediaPickerBlock(nil)
    }

    func changeAvatar(to avatar: UIImage?) {
        if let avatar = avatar as UIImage? {
            let scaledImage = avatar.resized(toHeight: 320)
            avatarImageView.image = scaledImage
        }
    }

    func displayCamera(from cameraView: AttachmentCameraView?, menu: MenuSheetController, carouselItem _: AttachmentCarouselItemView) {
        var controller: CameraController
        let screenSize = TGScreenSize()

        if let previewView = cameraView?.previewView() as CameraPreviewView? {
            controller = CameraController(camera: previewView.camera, previewView: previewView, intent: CameraControllerAvatarIntent)!
        } else {
            controller = CameraController()
        }

        controller.isImportant = true
        controller.shouldStoreCapturedAssets = true
        controller.allowCaptions = true

        let controllerWindow = CameraControllerWindow(parentController: self, contentController: controller)
        controllerWindow?.isHidden = false

        controllerWindow?.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)

        var startFrame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height)

        if let cameraView = cameraView as AttachmentCameraView?, let frame = cameraView.previewView().frame as CGRect? {
            startFrame = controller.view.convert(frame, from: cameraView)
        }

        cameraView?.detachPreviewView()
        controller.beginTransitionIn(from: startFrame)

        controller.beginTransitionOut = {

            if let cameraView = cameraView as AttachmentCameraView? {

                cameraView.willAttachPreviewView()
                return controller.view.convert(cameraView.frame, from: cameraView.superview)
            }

            return CGRect.zero
        }

        controller.finishedTransitionOut = {
            cameraView?.attachPreviewView(animated: true)
        }

        controller.finishedWithPhoto = { resultImage, _, _ in

            menu.dismiss(animated: true)
            self.changeAvatar(to: resultImage)
        }
    }

    func cancelAndDismiss() {
        navigationController?.popViewController(animated: true)
    }

    func saveAndDismiss() {
        guard let user = TokenUser.current else { return }

        var username = ""
        var name = ""
        var about = ""
        var location = ""
        var isPublic = false

        // we use flatmap here to map nested array into one
        let editedItems = editingSections.flatMap { section in
            return section.items
        }

        editedItems.forEach { item in
            let text = item.detailText

            switch item.type {
            case .username:
                username = text
            case .displayName:
                name = text
            case .about:
                about = text
            case .location:
                location = text
            case .visibility:
                isPublic = item.switchMode
            default:
                break
            }
        }

        view.endEditing(true)

        if validateUserName(username) == false {
            let alert = UIAlertController.dismissableAlert(title: "Error", message: "Username is invalid! Use numbers, letters, and underscores only.")
            Navigator.presentModally(alert)

            return
        }

        activityIndicator.startAnimating()

        let userDict: [String: Any] = [
            TokenUser.Constants.address: user.address,
            TokenUser.Constants.paymentAddress: user.paymentAddress,
            TokenUser.Constants.username: username,
            TokenUser.Constants.about: about,
            TokenUser.Constants.location: location,
            TokenUser.Constants.name: name,
            TokenUser.Constants.avatar: user.avatarPath,
            TokenUser.Constants.isApp: user.isApp,
            TokenUser.Constants.isPublic: isPublic,
            TokenUser.Constants.verified: user.verified
        ]

        idAPIClient.updateUser(userDict) { userUpdated, message in

            let cachedAvatar = AvatarManager.shared.cachedAvatar(for: user.avatarPath)

            if let image = self.avatarImageView.image as UIImage?, image != cachedAvatar {

                self.idAPIClient.updateAvatar(image) { avatarUpdated in
                    let success = userUpdated == true && avatarUpdated == true

                    self.completeEdit(success: success, message: message)
                }
            } else {
                self.completeEdit(success: userUpdated, message: message)
            }
        }
    }

    fileprivate func validateUserName(_ username: String) -> Bool {
        let none = NSRegularExpression.MatchingOptions(rawValue: 0)
        let range = NSRange(location: 0, length: username.characters.count)

        var isValid = true

        if isValid {
            isValid = username.characters.count >= 2
        }

        if isValid {
            isValid = username.characters.count <= 60
        }

        var regex: NSRegularExpression?
        do {
            let pattern = IDAPIClient.usernameValidationPattern
            regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .dotMatchesLineSeparators, .useUnicodeWordBoundaries])
        } catch {
            fatalError("Invalid regular expression pattern")
        }

        if isValid {
            if let validationRegex = regex {
                isValid = validationRegex.numberOfMatches(in: username, options: none, range: range) >= 1
            }
        }

        return isValid
    }

    fileprivate func completeEdit(success: Bool, message: String?) {
        activityIndicator.stopAnimating()

        if success == true {
            navigationController?.popViewController(animated: true)
        } else {
            let alert = UIAlertController.dismissableAlert(title: "Error", message: message ?? "Something went wrong")
            Navigator.presentModally(alert)
        }
    }

    @objc private func didTapView(sender: UITapGestureRecognizer) {
        if sender.state == .recognized {
            becomeFirstResponder()
        }
    }

    fileprivate lazy var activityIndicator: UIActivityIndicatorView = {
        // need to initialize with large style which is available only white, thus need to set color later
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicator.color = Theme.lightGreyTextColor
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        return activityIndicator
    }()
}

extension ProfileEditController: ImagePickerDelegate {

    public func wrapperDidPress(_: ImagePickerController, images _: [UIImage]) {
    }

    public func doneButtonDidPress(_: ImagePickerController, images: [UIImage]) {
        guard let image = images.first else { return }

        changeAvatar(to: image)
    }

    public func cancelButtonDidPress(_: ImagePickerController) {
        dismiss(animated: true)
    }
}

extension ProfileEditController: UITableViewDelegate {

    public func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
}

extension ProfileEditController: UITableViewDataSource {

    public func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? "Profile Visibility" : nil
    }

    public func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        let editingSection = editingSections[section]

        return editingSection.footerTitle
    }

    public func numberOfSections(in _: UITableView) -> Int {
        return editingSections.count
    }

    public func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let editingSection = editingSections[section]

        return editingSection.items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(InputCell.self, for: indexPath)

        let section = editingSections[indexPath.section]
        let item = section.items[indexPath.row]

        let configurator = ProfileEditConfigurator(item: item)
        configurator.configure(cell: cell)

        return cell
    }
}
