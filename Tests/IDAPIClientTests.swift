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
class IDAPIClientTests: QuickSpec {

    override func spec() {
        describe("the id API Client") {

            context("Happy path 😎") {
                var subject: IDAPIClient!
                let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self))
                subject = IDAPIClient(teapot: mockTeapot)

                it("fetches the timestamp") {
                    waitUntil { done in
                        subject.fetchTimestamp { timestamp in
                            expect(timestamp).toNot(beNil())
                            done()
                         }
                    }
                }

                it("registers user if needed") {
                    waitUntil { done in
                        subject.registerUserIfNeeded { status, message in
                            expect(status).to(equal(UserRegisterStatus.registered))
                            done()
                         }
                    }
                }

//                it("doesn't registers user if it's already existing") {
//                    waitUntil { done in
//                        subject.registerUserIfNeeded { status, message in
//                            expect(status.rawValue).to(equal(UserRegisterStatus.registered.rawValue))
//                            subject.registerUserIfNeeded { status, message in
//                                expect(status.rawValue).to(equal(UserRegisterStatus.existing.rawValue))
//                                done()
//                            }
//                        }
//                    }
//                }

                it("updates Avatar") {
                    let testImage = UIImage(named: "testImage.png", in: Bundle(for: IDAPIClientTests.self), compatibleWith: nil)
                    waitUntil { done in
                        subject.updateAvatar(testImage!) { success in
                            expect(success).to(beTruthy())
                            done()
                        }
                    }
                }
                
                it("updates the user") {
                    let userDict: [String: Any] = [
                        "token_id": "van Diemenstraat 328",
                        "payment_address": "Longstreet 200",
                        "username": "marijn2000",
                        "about": "test user dict!",
                        "location": "Leiden",
                        "name": "Marijntje",
                        "avatar": "someURL",
                        "is_app": false,
                        "public": true,
                        "verified": false
                    ]

                    waitUntil { done in
                        subject.updateUser(userDict) { success, message in
                            expect(success).to(beTruthy())
                            expect(message).to(beNil())
                            done()
                        }
                    }
                }

                it("retrieve contact") {
                    let username = "testUsername"

                    waitUntil { done in
                        subject.retrieveContact(username: username) { user in
                            expect(user).toNot(beNil())
                            done()
                        }
                    }
                }

                it("retrieve user") {
                    let username = "testUsername"

                    waitUntil { done in
                        subject.retrieveUser(username: username) { user in
                            expect(user).toNot(beNil())
                            done()
                        }
                    }
                }

                it("finds a contact") {
                    let username = "testUsername"

                    waitUntil { done in
                        subject.findContact(name: username) { user in
                            expect(user).toNot(beNil())
                            done()
                        }
                    }
                }

                it("searches contacts") {
                    let search = "search key"

                    waitUntil { done in
                        subject.searchContacts(name: search) { users in
                            expect(users.count).to(equal(2))
                            expect(users.first!.name).to(equal("Search result 1"))
                            done()
                        }
                    }
                }

                it("gets top rated public users") {
                    let search = "search key"

                    waitUntil { done in
                        subject.getTopRatedPublicUsers { users, error in
                            expect(users!.count ?? 0).to(equal(2))
                            expect(users!.first!.about).to(equal("Top rated"))
                            done()
                        }
                    }
                }

                it("gets top latest public users") {
                    let search = "search key"

                    waitUntil { done in
                        subject.getLatestPublicUsers { users, error in
                            print(error)
                            expect(users!.count ?? 0).to(equal(2))
                            expect(users!.first!.about ).to(equal("Latest public"))
                            done()
                        }
                    }
                }
            }
        }
    }
}
//swiftlint:enable force_cast