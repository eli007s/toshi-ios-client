import XCTest
import UIKit
import Quick
import Nimble

//swiftlint:disable force_cast
class FailingEthereumConverterTests: QuickSpec {

    let weisToEtherConstant = NSDecimalNumber(string: "1000000000000000000")
    
    override func spec() {
        describe("the Ethereum Converter") {
            context("overflowing tests") {

                for i in 0...1000 {
                    var randomDecimalPart1 = Decimal(arc4random_uniform(1000000000))
                    let randomDecimalPart2 = Decimal(arc4random_uniform(1000000000))

                    randomDecimalPart1.multiply(by: randomDecimalPart2)
                    let exchangeRate: Decimal = randomDecimalPart1 / Decimal(1000000000000000000)

                    let wei = NSDecimalNumber(decimal: 3809088485125510208453626017697492.5299999999999488)

                    it("gets the fiat value for wei") {
                        let fiat = EthereumConverter.fiatValueForWei(wei, exchangeRate: exchangeRate)
                        print("RESULT FIAT ==== \(fiat)")
                        print("")

                        expect(fiat).toNot(be(0))
                    }
                }
            }
        }
    }
}
//swiftlint:enable force_cast
