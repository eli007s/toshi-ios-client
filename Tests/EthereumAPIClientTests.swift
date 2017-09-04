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

import XCTest
import UIKit
import Quick
import Nimble
import Teapot

//swiftlint:disable force_cast
class EthereumAPIClientTests: QuickSpec {

    override func spec() {
        describe("the Ethereum API Client") {
            var subject: EthereumAPIClient!

            context("Happy path 😎") {
                it("creates an unsigned transaction") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: EthereumAPIClientTests.self), mockFileName: "createUnsignedTransaction")
                    subject = EthereumAPIClient(mockTeapot: mockTeapot)

                    let parameters: [String: Any] = [
                        "from": "0x011c6dd9565b8b83e6a9ee3f06e89ece3251ef2f",
                        "to": "0x011c6dd9565b8b83e6a9ee3f06e89ece3251ef2f",
                        "value": 1000
                    ]

                    waitUntil { done in
                        subject.createUnsignedTransaction(parameters: parameters) { transaction, error in
                            expect(transaction).toNot(beNil())
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }

                it("sends a signed transaction") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: EthereumAPIClientTests.self), mockFileName: "sendSignedTransaction")
                    mockTeapot.overrideEndPoint("timestamp", withFileName: "timestamp")
                    subject = EthereumAPIClient(mockTeapot: mockTeapot)

                    waitUntil(timeout: 3) { done in
                        let originalTransaction = "0xf085746f6b658d8504a817c800825208945c156634bc3aed611e71550fb8a54480b480cd3b8718972b8c63638a80748080"
                        let transactionSignature = "0x4f80931676670df5b7a919aeaa56ae1d0c2db1792e6e252ee66a30007022200e44f61e710dbd9b24bed46338bed73f21e3a1f28ac791452fde598913867ebbb701"
                        subject.sendSignedTransaction(originalTransaction: originalTransaction, transactionSignature: transactionSignature) { json, error in
                            expect(json).toNot(beNil())
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }

                it("gets the balance") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: EthereumAPIClientTests.self), mockFileName: "getBalance")
                    subject = EthereumAPIClient(mockTeapot: mockTeapot)

                    waitUntil { done in
                        subject.getBalance(address: "0x1ad0bb2d14595fa6ad885e53eaaa6c82339f9b98") { _, error in
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }
            }

            context("⚠ Unauthorized error 🔒") {
                it("creates an unsigned transaction") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: EthereumAPIClientTests.self), mockFileName: "createUnsignedTransaction", statusCode: .unauthorized)
                    subject = EthereumAPIClient(mockTeapot: mockTeapot)

                    let parameters: [String: Any] = [
                        "from": "0x011c6dd9565b8b83e6a9ee3f06e89ece3251ef2f",
                        "to": "0x011c6dd9565b8b83e6a9ee3f06e89ece3251ef2f",
                        "value": 1000
                    ]

                    waitUntil { done in
                        subject.createUnsignedTransaction(parameters: parameters) { transaction, error in
                            expect(error).toNot(beNil())
                            expect(transaction).to(beNil())
                            done()
                        }
                    }
                }

                it("sends a signed transaction") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: EthereumAPIClientTests.self), mockFileName: "sendSignedTransaction", statusCode: .unauthorized)
                    mockTeapot.overrideEndPoint("timestamp", withFileName: "timestamp")
                    subject = EthereumAPIClient(mockTeapot: mockTeapot)

                    waitUntil(timeout: 3) { done in
                        let originalTransaction = "0xf085746f6b658d8504a817c800825208945c156634bc3aed611e71550fb8a54480b480cd3b8718972b8c63638a80748080"
                        let transactionSignature = "0x4f80931676670df5b7a919aeaa56ae1d0c2db1792e6e252ee66a30007022200e44f61e710dbd9b24bed46338bed73f21e3a1f28ac791452fde598913867ebbb701"
                        subject.sendSignedTransaction(originalTransaction: originalTransaction, transactionSignature: transactionSignature) { json, error in
                            expect(error).toNot(beNil())
                            expect(json).to(beNil())
                            done()
                        }
                    }
                }

                it("gets the balance") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: EthereumAPIClientTests.self), mockFileName: "getBalance", statusCode: .unauthorized)
                    subject = EthereumAPIClient(mockTeapot: mockTeapot)

                    waitUntil { done in
                        subject.getBalance(address: "0x1ad0bb2d14595fa6ad885e53eaaa6c82339f9b98") { number, error in
                            expect(error).toNot(beNil())
                            expect(number).to(equal(0))
                            done()
                        }
                    }
                }
            }
        }
    }
}
//swiftlint:enable force_cast
