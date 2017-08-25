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
            }
        }
    }
}
//swiftlint:enable force_cast