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
import Teapot
import AwesomeCache

final class AvatarManager: NSObject, CacheExpiryDefault {

    static let shared = AvatarManager()

    private lazy var imageCache: Cache<UIImage> = {
        do {
            return try Cache<UIImage>(name: "imageCache")
        } catch {
            fatalError("Couldn't instantiate the image cache")
        }
    }()

    private var teapots = [String: Teapot]()

    private lazy var downloadOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "Download avatars queue"

        return queue
    }()

    func avatar(for path: String, completion: @escaping ((UIImage?, String?) -> Void)) {
        guard let avatar = imageCache.object(forKey: path) else {
            downloadAvatar(path: path) { image in
                completion(image, path)
            }

            return
        }

        completion(avatar, path)
    }

    func cachedAvatar(for path: String) -> UIImage? {
        return imageCache.object(forKey: path)
    }

    func refreshAvatar(at path: String) {
        imageCache.removeObject(forKey: path)
    }

    func cleanCache() {
        imageCache.removeAllObjects()
    }

    func startDownloadContactsAvatars() {
        downloadOperationQueue.cancelAllOperations()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let contactsManager = appDelegate.contactsManager as ContactsManager? else { return }

            let avatarPaths = contactsManager.tokenContacts.flatMap { contact in
                contact.avatarPath as String
            }
            if let currentUserAvatarPath = TokenUser.current?.avatarPath as String? {
                self?.downloadAvatar(for: currentUserAvatarPath)
            }

            for path in avatarPaths {
                if operation.isCancelled { return }
                self?.downloadAvatar(for: path)
            }
        }

        downloadOperationQueue.addOperation(operation)
    }

    private func downloadAvatar(for path: String) {
        guard imageCache.object(forKey: path) == nil else {
            return
        }

        downloadAvatar(path: path) { _ in }
    }

    private func baseURL(from url: URL) -> String? {
        if url.baseURL == nil {
            guard let scheme = url.scheme, let host = url.host else { return nil }
            return "\(scheme)://\(host)"
        }

        return url.baseURL?.absoluteString
    }

    private func teapot(for url: URL) -> Teapot? {
        guard let base = baseURL(from: url) as String? else { return nil }
        if teapots[base] == nil {
            guard let baseUrl = URL(string: base) as URL? else { return nil }
            teapots[base] = Teapot(baseURL: baseUrl)
        }

        return teapots[base]
    }

    func downloadAvatar(path: String, completion: @escaping (_ image: UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = URL(string: path) as URL?,
                let teapot = self.teapot(for: url) as Teapot? else {
                    completion(nil)
                    return
            }

            teapot.get(url.relativePath) { [weak self] (result: NetworkImageResult) in
                guard let strongSelf = self else {
                    completion(nil)
                    return
                }

                switch result {
                case .success(let image, _):
                    strongSelf.imageCache.setObject(image, forKey: path, expires: strongSelf.cacheExpiry)
                    completion(image)
                case .failure(let response, let error):
                    print(response)
                    print(error)
                    completion(nil)
                }
            }
        }
    }
}
