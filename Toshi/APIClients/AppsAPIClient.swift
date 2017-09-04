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
import AwesomeCache
import Teapot
import UIKit

public class AppsAPIClient: NSObject, CacheExpiryDefault {
    static let shared: AppsAPIClient = AppsAPIClient()

    private var teapot: Teapot

    override init() {
        teapot = Teapot(baseURL: URL(string: ToshiIdServiceBaseURLPath)!)
    }

    convenience init(teapot: Teapot) {
        self.init()
        self.teapot = teapot
    }

    func getTopRatedApps(limit: Int = 10, completion: @escaping (_ apps: [TokenUser]?, _ error: Error?) -> Void) {
        self.teapot.get("/v1/search/apps?top=true&recent=false&limit=\(limit)") { (result: NetworkResult) in
            var resultsError: Error?
            var results: [TokenUser] = []
            switch result {
            case .success(let json, _):
                guard let json = json?.dictionary, let appsJSON = json["results"] as? [[String: Any]] else {
                    completion(nil, nil)
                    return
                }

                let apps = appsJSON.map { json -> TokenUser in
                    TokenUser(json: json)
                }

                results = apps
            case .failure(_, _, let error):
                resultsError = error
            }

            DispatchQueue.main.async {
                completion(results, resultsError)
            }
        }
    }

    func getFeaturedApps(limit: Int = 10, completion: @escaping (_ apps: [TokenUser]?, _ error: Error?) -> Void) {
        self.teapot.get("/v1/search/apps?top=false&recent=true&limit=\(limit)") { (result: NetworkResult) in
            var resultsError: Error?
            var results: [TokenUser] = []

            switch result {
            case .success(let json, _):
                guard let json = json?.dictionary, let appsJSON = json["results"] as? [[String: Any]] else {
                    completion(nil, nil)
                    return
                }

                let apps = appsJSON.map { json in
                    TokenUser(json: json)
                }

                results = apps
            case .failure(_, _, let error):
                resultsError = error
            }

            DispatchQueue.main.async {
                completion(results, resultsError)
            }
        }
    }

    func search(_ searchTerm: String, limit: Int = 100, completion: @escaping (_ apps: [TokenUser], _ error: Error?) -> Void) {
        guard !searchTerm.isEmpty else {
            completion([TokenUser](), nil)
            return
        }

        let query = searchTerm.addingPercentEncoding(withAllowedCharacters: IDAPIClient.allowedSearchTermCharacters) ?? searchTerm
        self.teapot.get("/v1/search/apps/?query=\(query)&limit=\(limit)") { (result: NetworkResult) in
            var resultsError: Error?
            var results: [TokenUser] = []

            switch result {
            case .success(let json, _):
                guard let json = json?.dictionary else {
                    completion([], nil)

                    return
                }

                guard let appsJSON = json["results"] as? [[String: Any]] else {
                    completion([TokenUser](), nil)
                    return
                }

                let apps = appsJSON.map { json -> TokenUser in
                    return TokenUser(json: json)
                }

                results = apps
            case .failure(_, _, let error):
                resultsError = error
            }

            DispatchQueue.main.async {
                completion(results, resultsError)
            }
        }
    }
}
