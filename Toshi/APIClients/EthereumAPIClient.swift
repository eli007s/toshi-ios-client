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

public class EthereumAPIClient: NSObject {

    static let shared: EthereumAPIClient = EthereumAPIClient()

    fileprivate var mainTeapot: Teapot

    fileprivate var switchedNetworkTeapot: Teapot

    fileprivate var activeTeapot: Teapot {
        if NetworkSwitcher.shared.isDefaultNetworkActive {
            return mainTeapot
        } else {
            return switchedNetworkTeapot
        }
    }

    fileprivate static var teapotUrl: String {
        return NetworkSwitcher.shared.activeNetworkBaseUrl
    }

    convenience init(mockTeapot: MockTeapot) {
        self.init()
        self.switchedNetworkTeapot = mockTeapot
        self.mainTeapot = mockTeapot
    }

    fileprivate override init() {
        mainTeapot = Teapot(baseURL: URL(string: NetworkSwitcher.shared.defaultNetworkBaseUrl)!)
        switchedNetworkTeapot = Teapot(baseURL: URL(string: NetworkSwitcher.shared.defaultNetworkBaseUrl)!)

        super.init()
    }

    public func createUnsignedTransaction(parameters: [String: Any], completion: @escaping ((_ unsignedTransaction: String?, _ error: Error?) -> Void)) {
        let json = RequestParameter(parameters)

        DispatchQueue.global(qos: .userInitiated).async {
            self.activeTeapot.post("/v1/tx/skel", parameters: json) { result in
                switch result {
                case .success(let json, let response):
                    print(response)
                    completion(json!.dictionary!["tx"] as? String, nil)
                case .failure(let json, let response, let error):
                    print(response)
                    print(json ?? "")
                    print(error)
                    completion(nil, error)
                }
            }
        }
    }

    public func sendSignedTransaction(originalTransaction: String, transactionSignature: String, completion: @escaping ((_ json: RequestParameter?, _ error: Error?) -> Void)) {
        timestamp(activeTeapot) { timestamp, error in
            guard let timestamp = timestamp else {
                completion(nil, error)
                return
            }

            let cereal = Cereal.shared
            let path = "/v1/tx"
            let params = [
                "tx": originalTransaction,
                "signature": transactionSignature
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: params, options: []), let payloadString = String(data: data, encoding: .utf8) else {
                print("Invalid payload, request could not be executed")
                completion(nil, nil)
                return
            }

            let hashedPayload = cereal.sha3WithWallet(string: payloadString)
            let signature = "0x\(cereal.signWithWallet(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

            let headers: [String: String] = [
                "Token-ID-Address": cereal.paymentAddress,
                "Token-Signature": signature,
                "Token-Timestamp": timestamp
            ]

            let json = RequestParameter(params)

            DispatchQueue.global(qos: .userInitiated).async {
                self.activeTeapot.post(path, parameters: json, headerFields: headers) { result in
                    switch result {
                    case .success(let json, let response):
                        print(response)
                        print(json ?? "")
                        completion(json, nil)
                    case .failure(let json, let response, let error):
                        print(response)
                        print(json ?? "")
                        print(error)
                        guard let jsonError = (json?.dictionary?["errors"] as? [[String: Any]])?.first else {
                            completion(nil, error)
                            return
                        }
                        
                        let json = RequestParameter(jsonError)
                        completion(json, error)
                    }
                }
            }
        }
    }

    public func getBalance(address: String, completion: @escaping ((_ balance: NSDecimalNumber, _ error: Error?) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.activeTeapot.get("/v1/balance/\(address)") { (result: NetworkResult) in
                switch result {
                case .success(let json, let response):
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedFailureReasonErrorKey: "Could not fetch balance."])
                    guard response.statusCode == 200 else { completion(0, error); return }
                    guard let json = json?.dictionary else { completion(0, error); return }

                    let unconfirmedBalanceString = json["unconfirmed_balance"] as? String ?? "0"
                    let unconfirmedBalance = NSDecimalNumber(hexadecimalString: unconfirmedBalanceString)

                    TokenUser.current?.balance = unconfirmedBalance

                    completion(unconfirmedBalance, nil)
                case .failure(let json, let response, let error):
                    completion(0, error)
                    print(error)
                    print(response)
                    print(json ?? "")
                }
            }
        }
    }

    public func registerForMainNetworkPushNotifications() {
        timestamp(mainTeapot) { timestamp, error in
            guard let timestamp = timestamp else { return }

            self.registerForPushNotifications(timestamp, teapot: self.mainTeapot) { _ in
            }
        }
    }

    public func registerForSwitchedNetworkPushNotificationsIfNeeded(completion: ((_ success: Bool, _ message: String?) -> Void)? = nil) {
        guard NetworkSwitcher.shared.isDefaultNetworkActive == false else {
            completion?(true, nil)
            return
        }

        switchedNetworkTeapot.baseURL = URL(string: NetworkSwitcher.shared.activeNetworkBaseUrl)!

        timestamp(switchedNetworkTeapot) { timestamp, error in
            guard let timestamp = timestamp else { return }
            self.registerForPushNotifications(timestamp, teapot: self.switchedNetworkTeapot, completion: completion)
        }
    }

    public func deregisterFromMainNetworkPushNotifications() {
        timestamp(mainTeapot) { timestamp, error in
            guard let timestamp = timestamp else { return }
            self.deregisterFromPushNotifications(timestamp, teapot: self.mainTeapot)
        }
    }

    public func deregisterFromSwitchedNetworkPushNotifications(completion: ((_ success: Bool, _ message: String?) -> Void)? = nil) {
        timestamp(switchedNetworkTeapot) { timestamp, error in
            guard let timestamp = timestamp else { return }
            self.deregisterFromPushNotifications(timestamp, teapot: self.switchedNetworkTeapot, completion: completion)
        }
    }

    fileprivate func timestamp(_ teapot: Teapot, _ completion: @escaping ((_ timestamp: String?, _ error: Error?) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            teapot.get("/v1/timestamp") { (result: NetworkResult) in
                switch result {
                case .success(let json, _):
                    guard let json = json?.dictionary else { fatalError() }
                    guard let timestamp = json["timestamp"] as? Int else { fatalError("Timestamp should be an integer") }

                    completion(String(timestamp), nil)
                case .failure(_, _, let error):
                    completion(nil, error)
                    print(error)
                }
            }
        }
    }

    fileprivate func registerForPushNotifications(_ timestamp: String, teapot: Teapot, completion: ((_ success: Bool, _ message: String?) -> Void)? = nil) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let cereal = Cereal.shared
        let path = "/v1/apn/register"
        let address = cereal.address
        let params = ["registration_id": appDelegate.token, "address": cereal.paymentAddress]

        guard let data = try? JSONSerialization.data(withJSONObject: params, options: []), let payloadString = String(data: data, encoding: .utf8) else {
            completion?(false, "Invalid payload, request could not be executed")
            return
        }

        let hashedPayload = cereal.sha3WithID(string: payloadString)
        let signature = "0x\(cereal.signWithID(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

        let headerFields: [String: String] = [
            "Token-ID-Address": address,
            "Token-Signature": signature,
            "Token-Timestamp": timestamp
        ]

        let json = RequestParameter(params)

        DispatchQueue.global(qos: .userInitiated).async {
            teapot.post(path, parameters: json, headerFields: headerFields) { result in
                switch result {
                case .success(let json, let response):
                    print(json ?? "")
                    print(response)
                    print("\n +++ Registered for :\(teapot.baseURL)")

                    completion?(true, "json: \(json?.dictionary ?? [String: Any]()) response: \(response)")
                case .failure(let json, let response, let error):
                    print(json ?? "")
                    print(response)
                    print(error)

                    completion?(false, "json: \(json?.dictionary ?? [String: Any]()) response: \(response), error: \(error)")
                }
            }
        }
    }

    fileprivate func deregisterFromPushNotifications(_ timestamp: String, teapot: Teapot, completion: ((_ success: Bool, _ message: String?) -> Void)? = nil) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let cereal = Cereal.shared
        let address = cereal.paymentAddress
        let path = "/v1/apn/deregister"

        let params = ["registration_id": appDelegate.token, "address": cereal.paymentAddress]

        guard let data = try? JSONSerialization.data(withJSONObject: params, options: []), let payloadString = String(data: data, encoding: .utf8) else {
            completion?(false, "Invalid payload, request could not be executed")
            return
        }

        let hashedPayload = cereal.sha3WithWallet(string: payloadString)
        let signature = "0x\(cereal.signWithWallet(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

        let headerFields: [String: String] = [
            "Token-ID-Address": address,
            "Token-Signature": signature,
            "Token-Timestamp": timestamp
        ]

        let json = RequestParameter(params)

        DispatchQueue.global(qos: .userInitiated).async {
            teapot.post(path, parameters: json, headerFields: headerFields) { result in
                switch result {
                case .success(let json, let response):
                    print(json ?? "")
                    print(response)

                    print("\n --- DE-registered from :\(teapot.baseURL)")

                    completion?(true, "json:\(json?.dictionary ?? [String: Any]()), response: \(response)")
                case .failure(let json, let response, let error):
                    print(json ?? "")
                    print(response)
                    print(error)

                    completion?(false, "json:\(json?.dictionary ?? [String: Any]()), response: \(response), error: \(error)")
                }
            }
        }
    }
}
