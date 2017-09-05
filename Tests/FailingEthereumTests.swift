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
                    let randomDecimalPart3 = Decimal(arc4random_uniform(arc4random_uniform(10000)))

                    randomDecimalPart1.multiply(by: randomDecimalPart2)
                    randomDecimalPart1.multiply(by: randomDecimalPart3)
                    let randomExchangeRate: Decimal = randomDecimalPart1 / Decimal(1000000000000000000)

                    var randomWeiPart1 = Decimal(arc4random_uniform(1000000000))
                    let randomWeiPart2 = Decimal(arc4random_uniform(arc4random_uniform(1000000000)))

                    randomWeiPart1.multiply(by: randomWeiPart2)
                    
                    let randomWei = NSDecimalNumber(decimal: randomDecimalPart1 / Decimal(10000))

                    it("gets the fiat value for wei") {
                        let fiat = EthereumConverter.fiatValueForWei(randomWei, exchangeRate: randomExchangeRate)
                        let string = EthereumConverter.fiatValueString(forWei: randomWei, exchangeRate: randomExchangeRate)
                        let currency = EthereumConverter.fiatValueStringWithCode(forWei: randomWei, exchangeRate: randomExchangeRate)
                        print("exchangeRate \t\t==== \(randomExchangeRate)")
                        print("wei \t\t\t\t==== \(randomWei)")
                        print("fiat \t\t\t\t==== \(fiat)")
                        print("string \t\t\t\t==== \(string)")
                        print("currency \t\t\t==== \(string) \n\n")

                        expect(fiat).toNot(be(0))
                    }
                }
            }
        }
    }
}
//swiftlint:enable force_cast
