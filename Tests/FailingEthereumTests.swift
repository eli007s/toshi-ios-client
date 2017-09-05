import XCTest
import UIKit
import Quick
import Nimble

//swiftlint:disable force_cast
class EthereumConverterTests: QuickSpec {

    override func spec() {
        describe("the Ethereum Converter") {
            context("overflowing tests") {
                let exchangeRate: Decimal = 0.02311
                let wei: NSDecimalNumber = 1000000000000000000

                it("returns a string representation in eht for a given wei value") {
                    let ethereumValueString = EthereumConverter.ethereumValueString(forWei: wei)

                    expect(ethereumValueString).to(equal("1.0000 ETH"))
                }

                it("returns fiat currency value string with redundant 3 letter code") {
                    let ethereumValueString = EthereumConverter.fiatValueStringWithCode(forWei: wei, exchangeRate: exchangeRate)

                    let dollarSting = String(format: "$100%@00 USD", TokenUser.current?.cachedCurrencyLocale?.decimalSeparator ?? ".")
                    expect(ethereumValueString).to(equal(dollarSting))
                }
            }
        }
    }
}
//swiftlint:enable force_cast
