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

import Foundation

enum DisplayState {
    case hide
    case show
    case hideAndShow
    case doNothing
}

protocol ChatViewModelOutput: ChatInteractorOutput {
    func didReload()
    func didRequireKeyboardVisibilityUpdate(_ sofaMessage: SofaMessage)
    func didReceiveLastMessage()
}

final class ChatViewModel {

    fileprivate weak var output: ChatViewModelOutput?

    init(output: ChatViewModelOutput, thread: TSThread) {
        self.output = output
        self.thread = thread

        storageManager = TSStorageManager.shared()

        countAllMessages()

        loadNextChunk(notifiesAboutLastMessage: true)

        registerNotifications()

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        contactsManager = appDelegate?.contactsManager
    }

    fileprivate var contactsManager: ContactsManager?

    fileprivate var etherAPIClient: EthereumAPIClient {
        return EthereumAPIClient.shared
    }

    private(set) var thread: TSThread

    private(set) lazy var interactor: ChatsInteractor = {
        ChatsInteractor(output: self.output, thread: self.thread)
    }()

    var contact: TokenUser? {
        return contactsManager?.tokenContact(forAddress: thread.contactIdentifier())
    }

    var currentButton: SofaMessage.Button?

    var messageModels: [MessageModel] = []

    fileprivate lazy var reloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "Chat-Reload-Queue"

        return queue
    }()

    private(set) var messages: [Message] = [] {
        didSet {
            reloadQueue.cancelAllOperations()

            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self] in

                guard operation.isCancelled == false else { return }
                guard let strongSelf = self else { return }

                for message in strongSelf.messages {
                    if let paymentRequest = message.sofaWrapper as? SofaPaymentRequest {
                        message.fiatValueString = EthereumConverter.fiatValueStringWithCode(forWei: paymentRequest.value, exchangeRate: ExchangeRateClient.exchangeRate)
                        message.ethereumValueString = EthereumConverter.ethereumValueString(forWei: paymentRequest.value)
                    } else if let payment = message.sofaWrapper as? SofaPayment {
                        message.fiatValueString = EthereumConverter.fiatValueStringWithCode(forWei: payment.value, exchangeRate: ExchangeRateClient.exchangeRate)
                        message.ethereumValueString = EthereumConverter.ethereumValueString(forWei: payment.value)
                    }
                }

                strongSelf.visibleMessages = strongSelf.messages.filter { message -> Bool in
                    message.isDisplayable
                }

                guard operation.isCancelled == false else { return }

                DispatchQueue.main.async {
                    strongSelf.output?.didReload()
                }
            }

            reloadQueue.addOperation(operation)
        }
    }

    var visibleMessages: [Message] = [] {
        didSet {
            messageModels = visibleMessages.flatMap { MessageModel(message: $0) }
        }
    }

    func visibleMessage(at index: Int) -> Message {
        return visibleMessages[index]
    }

    func message(at index: Int) -> Message {
        return messages[index]
    }

    fileprivate var storageManager: TSStorageManager?

    fileprivate lazy var uiDatabaseConnection: YapDatabaseConnection = {
        let database = TSStorageManager.shared().database()!
        let dbConnection = database.newConnection()
        dbConnection.beginLongLivedReadTransaction()

        return dbConnection
    }()

    fileprivate lazy var rangeOptions: YapDatabaseViewRangeOptions = {
        let options = YapDatabaseViewRangeOptions.flexibleRange(withLength: 20, offset: 0, from: .end)!
        options.growOptions = .onBothSides

        return options
    }()

    fileprivate lazy var mappings: YapDatabaseViewMappings = {
        YapDatabaseViewMappings(groups: [self.thread.uniqueId], view: TSMessageDatabaseViewExtensionName)
    }()

    fileprivate lazy var loadedMappings: YapDatabaseViewMappings = {
        YapDatabaseViewMappings(groups: [self.thread.uniqueId], view: TSMessageDatabaseViewExtensionName)
    }()

    fileprivate lazy var editingDatabaseConnection: YapDatabaseConnection? = {
        self.storageManager?.newDatabaseConnection()
    }()

    fileprivate var messagesCount: UInt = 0
    fileprivate var loadedMessagesCount: UInt = 0

    fileprivate func registerNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(yapDatabaseDidChange(notification:)), name: .YapDatabaseModified, object: nil)
    }

    func saveDraftIfNeeded(inputViewText: String?) {
        let thread = self.thread
        guard let text = inputViewText else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            self.editingDatabaseConnection?.asyncReadWrite { transaction in
                thread.setDraft(text, transaction: transaction)
            }
        }
    }

    func updateMessagesRange(from indexPath: IndexPath? = nil) {
        loadNextChunk()
    }

    fileprivate func loadNextChunk(notifiesAboutLastMessage: Bool = false) {
        let nextChunkSize = self.nextChunkSize()

        guard let rangeOptions = YapDatabaseViewRangeOptions.flexibleRange(withLength: nextChunkSize, offset: loadedMessagesCount, from: .end) as YapDatabaseViewRangeOptions? else { return }
        self.loadedMappings.setRangeOptions(rangeOptions, forGroup: self.thread.uniqueId)

        self.loadMessages(notifiesAboutLastMessage: notifiesAboutLastMessage)
    }

    @objc
    fileprivate func yapDatabaseDidChange(notification _: NSNotification) {
        
        let notifications = uiDatabaseConnection.beginLongLivedReadTransaction()

        // If changes do not affect current view, update and return without updating collection view
        // TODO: Since this is used in more than one place, we should look into abstracting this away, into our own
        // table/collection view backing model.
        // swiftlint:disable force_cast
        let messageViewConnection = uiDatabaseConnection.ext(TSMessageDatabaseViewExtensionName) as! YapDatabaseViewConnection
        // swiftlint:enable force_cast
        if let hasChangesForCurrentView = messageViewConnection.hasChanges(for: notifications) as Bool?, hasChangesForCurrentView == false {
            uiDatabaseConnection.read { transaction in
                self.mappings.update(with: transaction)
            }

            return
        }

        let yapDatabaseChanges = messageViewConnection.getChangesFor(notifications: notifications, with: mappings)

        uiDatabaseConnection.asyncRead { [weak self] transaction in
            guard let strongSelf = self else { return }

            strongSelf.mappings.update(with: transaction)
            strongSelf.loadedMappings.update(with: transaction)

            for change in yapDatabaseChanges.rowChanges {

                guard let dbExtension = transaction.ext(TSMessageDatabaseViewExtensionName) as? YapDatabaseViewTransaction else { return }

                switch change.type {
                case .insert:
                    guard let signalMessage = dbExtension.object(at: change.newIndexPath, with: strongSelf.mappings) as? TSMessage else { return }

                    DispatchQueue.main.async {
                        let result = strongSelf.interactor.handleSignalMessage(signalMessage, shouldProcessCommands: true)

                        strongSelf.messages.insert(result, at: 0)

                        strongSelf.output?.didReceiveLastMessage()

                        if let sofaMessage = result.sofaWrapper as? SofaMessage {
                            strongSelf.output?.didRequireKeyboardVisibilityUpdate(sofaMessage)
                        }

                        strongSelf.interactor.playSound(for: result)

                        if let incoming = signalMessage as? TSIncomingMessage, !incoming.wasRead {
                            incoming.markAsReadLocally()
                        }
                    }

                case .update:
                    let indexPath = change.indexPath

                    guard let signalMessage = dbExtension.object(at: indexPath, with: strongSelf.mappings) as? TSMessage else { return }
                    guard let message = (strongSelf.messages.first { $0.signalMessage == signalMessage }) as Message? else { return }

                    DispatchQueue.main.async {
                        if let loadedSignalMessage = message.signalMessage as? TSOutgoingMessage, let newSignalMessage = signalMessage as? TSOutgoingMessage {
                            loadedSignalMessage.setState(newSignalMessage.messageState)
                        }

                        if let index = strongSelf.messages.index(of: message) as Int? {

                            let updatedMessage = strongSelf.interactor.handleSignalMessage(signalMessage, shouldProcessCommands: false)
                            strongSelf.messages[index] = updatedMessage
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    func reloadDraft(completion: @escaping ((String?) -> Void)) {
        let thread = self.thread
        var placeholder: String?

        DispatchQueue.global(qos: .userInitiated).async {
            self.editingDatabaseConnection?.asyncReadWrite({ transaction in
                placeholder = thread.currentDraft(with: transaction)
            }, completionBlock: {
                DispatchQueue.main.async {
                    completion(placeholder)
                }
            })
        }
    }

    func displayState(for button: SofaMessage.Button?) -> DisplayState {
        if let button = button, let currentButton = self.currentButton {
            if button == currentButton {
                return .hide
            } else {
                return .hideAndShow
            }
        }

        if button == nil && currentButton == nil {
            return .doNothing
        } else if button == nil && currentButton != nil {
            return .hide
        } else {
            return .show
        }
    }

    func fetchAndUpdateBalance(completion: @escaping ((NSDecimalNumber, Error?) -> Void)) {
        interactor.fetchAndUpdateBalance(completion: completion)
    }

    fileprivate func countAllMessages() {
        self.uiDatabaseConnection.read { [weak self] transaction in
            guard let strongSelf = self else { return }

            strongSelf.mappings.update(with: transaction)
            strongSelf.messagesCount = strongSelf.mappings.numberOfItems(inSection: 0)
        }
    }

    fileprivate func nextChunkSize() -> UInt {
        let notLoadedCount = messagesCount - loadedMessagesCount
        let numberToLoad = min(notLoadedCount, 50)

        return numberToLoad
    }

    func loadMessages(notifiesAboutLastMessage: Bool) {
        uiDatabaseConnection.asyncRead { [weak self] transaction in
            guard let strongSelf = self else { return }
            strongSelf.loadedMappings.update(with: transaction)

            var messages = [Message]()

            let numberOfItemsInSection = strongSelf.loadedMappings.numberOfItems(inSection: 0)
            strongSelf.loadedMessagesCount += numberOfItemsInSection

            for i in 0 ..< numberOfItemsInSection {
                let indexPath = IndexPath(row: Int(i), section: 0)
                guard let dbExtension = transaction.ext(TSMessageDatabaseViewExtensionName) as? YapDatabaseViewTransaction else { return }

                guard let signalMessage = dbExtension.object(at: indexPath, with: strongSelf.loadedMappings) as? TSMessage else { return }

                var shouldProcess = false
                if SofaType(sofa: signalMessage.body ?? "") == .paymentRequest {
                    shouldProcess = true
                }

                messages.append(strongSelf.interactor.handleSignalMessage(signalMessage, shouldProcessCommands: shouldProcess))
            }

            let current = Set(messages)
            let previous = Set(strongSelf.messages)
            let new = current.subtracting(previous).sorted { (message1, message2) -> Bool in
                // Signal splits media message in two separate messages, one with the attachments and one with text.
                // In this case two messages have the same Timestamp, we want to have the one with an attachment on top.
                if message1.date.compare(message2.date) == .orderedSame {
                    return message1.signalMessage.hasAttachments()
                }

                return message1.date.compare(message2.date) == .orderedAscending
            }.reversed()

            DispatchQueue.main.async {
                strongSelf.messages.append(contentsOf: new)

                if notifiesAboutLastMessage {
                    strongSelf.output?.didReceiveLastMessage()
                }
            }
        }
    }
}
