
import Foundation

struct CurrencyPair: Comparable, Codable {

var baseCurrency: Currency
    var quoteCurrency: Currency
    var customCode: String
    var marketCap: Double

    init(baseCurrency: Currency, quoteCurrency: Currency, customCode: String? = nil, marketCap : Double = 0) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency

        if let customCode = customCode {
            self.customCode = customCode
        } else {
            self.customCode = "\(baseCurrency.code)\(quoteCurrency.code)"
        }
        self.marketCap = marketCap
    }

    init?(baseCurrency: String?, quoteCurrency: String?, customCode: String? = nil, marketCap: Double = 0) {
        guard let baseCurrency = Currency(code: baseCurrency), let quoteCurrency = Currency(code: quoteCurrency) else {
            return nil
        }

        self = CurrencyPair(baseCurrency: baseCurrency,
                            quoteCurrency: quoteCurrency,
                            customCode: customCode,
                            marketCap: marketCap)
    }

}

extension CurrencyPair: CustomStringConvertible {

    var description: String {
        return "\(baseCurrency.code)\(quoteCurrency.code)"
    }

}

extension CurrencyPair: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: self))
    }

}

extension CurrencyPair: Equatable {

    static func <(lhs: CurrencyPair, rhs: CurrencyPair) -> Bool {
        // 按市值排序（降序）
          if lhs.marketCap != rhs.marketCap {
              return lhs.marketCap > rhs.marketCap
          }
        
        if lhs.baseCurrency == rhs.baseCurrency {
            return lhs.quoteCurrency < rhs.quoteCurrency
        }

        return lhs.baseCurrency < rhs.baseCurrency
    }

    static func == (lhs: CurrencyPair, rhs: CurrencyPair) -> Bool {
        return (lhs.baseCurrency == rhs.baseCurrency && lhs.quoteCurrency == rhs.quoteCurrency)
    }

}
