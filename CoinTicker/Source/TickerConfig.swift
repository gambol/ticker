
import Foundation
import Cocoa

class TickerConfig {

    private struct Keys {
        static let UserDefaultsExchangeSite = "userDefaults.exchangeSite"
        static let UserDefaultsUpdateInterval = "userDefaults.updateInterval"
        static let UserDefaultsShowIcon = "userDefaults.showIcon"
        static let UserDefaultsSelectedCurrencyPairs = "userDefaults.selectedCurrencyPairs"
        static let UserDefaultsPopoverCurrencyPairs = "userDefaults.selectedCurrencyCodesFromPopover"
        
        static let UserDefaultsFetchCoingeckoCoinIds = "userDefaults.userDefaultsFetchCoingeckoCoinIds"  // coingecko 的coinid和别的不一样
    }

    struct Constants {
        static let RealTimeUpdateInterval: Int = 15
    }

    static let LogoImage = NSImage(named: "CTLogo")!
    static let SmallLogoImage = NSImage(named: "CTLogo_small")!

    static var defaultExchange: Exchange {
        let exchange = defaultExchangeSite.exchange()
        exchange.updateInterval = defaultUpdateInterval
        if let selectedCurrencyPairs = defaultSelectedCurrencyPairs {
            exchange.menuBarCurrencies = selectedCurrencyPairs
        }

        return exchange
    }

    private static var defaultExchangeSite: ExchangeSite {
        get {
            let index = UserDefaults.standard.integer(forKey: Keys.UserDefaultsExchangeSite)
            return ExchangeSite(rawValue: index) ?? .gdax
        }

        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsExchangeSite)
        }
    }

    static var defaultUpdateInterval: Int {
        get {
            let updateInterval = UserDefaults.standard.integer(forKey: Keys.UserDefaultsUpdateInterval)
            return (updateInterval > 0 ? updateInterval : Constants.RealTimeUpdateInterval)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Keys.UserDefaultsUpdateInterval)
        }
    }

    static var showsIcon: Bool {
        get {
            guard UserDefaults.standard.value(forKey: Keys.UserDefaultsShowIcon) != nil else {
                return true
            }

            return UserDefaults.standard.bool(forKey: Keys.UserDefaultsShowIcon)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Keys.UserDefaultsShowIcon)
        }
    }
    

    
    // 新增属性，用于存储popover中选择的币种
       static var selectedCurrencyCodesFromPopover: Set<String> {
           get {
               if let storedCodes = UserDefaults.standard.array(forKey: Keys.UserDefaultsPopoverCurrencyPairs) as? [String] {
                   return Set(storedCodes)
               }
               // 默认选择一些常见币种
               return ["BTC"]
           }
           set {
               UserDefaults.standard.set(Array(newValue), forKey: Keys.UserDefaultsPopoverCurrencyPairs)
           }
       }
    
    // 新增方法，用于保存popover中选择的币种
    static func savePopoverSelection(_ selectedCodes: Set<String>) {
        selectedCurrencyCodesFromPopover = selectedCodes
    }

    static var userDefaultsFetchCoingeckoCoinIds: Set<String> {
        get {
            if let storedCodes = UserDefaults.standard.array(forKey: Keys.UserDefaultsFetchCoingeckoCoinIds) as? [String] {
                return Set(storedCodes)
            }
            // 默认选择一些常见币种
            return ["BTC"]
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Keys.UserDefaultsFetchCoingeckoCoinIds)
        }
    }
    
    // 新增方法，用于保存popover中选择的币种
    static func saveFetchCoinIds(_ selectedCodes: Set<String>) {
        userDefaultsFetchCoingeckoCoinIds = selectedCodes
    }

    private static var defaultSelectedCurrencyPairs: [CurrencyPair]? {
        get {
            if let data = UserDefaults.standard.object(forKey: Keys.UserDefaultsSelectedCurrencyPairs) as? Data {
                do {
                    return try JSONDecoder().decode([CurrencyPair].self, from: data)
                } catch {
                    print("Error reading from UserDefaults: \(error)")
                }
            }

            return []
        }

        set {
            do {
                UserDefaults.standard.set(try JSONEncoder().encode(newValue), forKey: Keys.UserDefaultsSelectedCurrencyPairs)
            } catch {
                print("Error saving to UserDefaults: \(error)")
            }
        }
    }

    static func save(_ defaultExchange: Exchange) {
        defaultExchangeSite = defaultExchange.site
        defaultUpdateInterval = defaultExchange.updateInterval
        defaultSelectedCurrencyPairs = defaultExchange.menuBarCurrencies
    }

}
