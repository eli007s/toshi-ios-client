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
class ChatAPIClientTests: QuickSpec {

    override func spec() {
        describe("the Chat API Client") {
            var subject: ChatAPIClient!

            context("Happy path 😎") {
                let mockTeapot = MockTeapot(bundle: Bundle(for: ChatAPIClientTests.self), mockFileName: "timestamp")
                subject = ChatAPIClient(teapot: mockTeapot)

                it("fetches timestamp") {
                    waitUntil { done in
                        subject.fetchTimestamp { timestamp, error in

                            expect(timestamp).toNot(beNil())
                            done()
                        }
                    }
                }
            }
        }
    }
}
//swiftlint:enable force_cast
