
import Foundation
import SwiftyJSON

class CoinGecko: Exchange {
    
    private struct Constants {
        static let CoinsListAPIPath = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1"
        static let PriceAPIPathFormat = "https://api.coingecko.com/api/v3/simple/price?ids=%@&vs_currencies=%@&include_24hr_change=true"
    }
    
    // Add storage for price changes
    public var priceChanges = [String: Double]()
    public var marketCaps = [String: Double]()
    
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .gateio, delegate: delegate)}
    
    override func load() {
        // 从CoinGecko加载币种列表，默认按市值排序
        requestAPI(Constants.CoinsListAPIPath).map { [weak self] result in
            guard let self = self else { return }
            
            // Clear existing market cap data
            self.marketCaps.removeAll()
            self.priceChanges.removeAll()
            let currencyPairs = self.processCoinGeckoResponse(result.json)
            
            // 排序逻辑
            let sortedPairs = self.sortCurrencyPairsByMarketCap(currencyPairs)
            
            // 调试输出
//            self.printTopCoins(sortedPairs)
            self.availableCurrencyPairs = sortedPairs
            // 处理选定的币种
            self.processSelectedCurrencyPairs()
            self.delegate?.exchange(self, didUpdateAvailableCurrencyPairs: self.availableCurrencyPairs)
            self.fetch()
        }.catch { error in
            print("Error loading CoinGecko markets: \(error)")
        }
    }
    
    // 处理CoinGecko响应的辅助方法
    private func processCoinGeckoResponse(_ json: JSON) -> [CurrencyPair] {
        guard let quoteCurrency = Currency(code:"USD") else  {
            return []
        }
        
        return json.arrayValue.compactMap { data -> CurrencyPair? in
            let id = data["id"].stringValue
            let symbol = data["symbol"].stringValue.uppercased()
            let marketCap = data["market_cap"].doubleValue
            let name = data["name"].stringValue
            
            let priceChange = data["price_change_percentage_24h"].doubleValue
            
            // Store market cap and price change info
            self.marketCaps[id] = marketCap
            self.priceChanges[id] = priceChange
            
            // 存储市值信息
            print("Coin: \(symbol), ID: \(id),  Market Cap: \(marketCap), priceChange: \(priceChange)")
            
            guard let base = Currency(customDisplayName: name, customSymbol: symbol) else {
                return nil
            }
            
            return CurrencyPair(
                baseCurrency: base,
                quoteCurrency: quoteCurrency,
                customCode: id,
                marketCap: marketCap
            )
        }
    }
    
    // 按市值排序币种对
    private func sortCurrencyPairsByMarketCap(_ pairs: [CurrencyPair]) -> [CurrencyPair] {
        return pairs.sorted { pair1, pair2 in
            let marketCap1 = self.marketCaps[pair1.customCode] ?? 0
            let marketCap2 = self.marketCaps[pair2.customCode] ?? 0
            return marketCap1 > marketCap2// 降序排列，市值大的在前
        }
    }
    
    // 打印前10名币种
    private func printTopCoins(_ sortedPairs: [CurrencyPair]) {
        print("Sorted coins:")
        for (index, pair) in sortedPairs.prefix(10).enumerated() {
            print("\(index+1). \(pair.baseCurrency): \(self.marketCaps[pair.customCode] ?? 0)")
        }}
    
    // 处理已选择的币种对
    private func processSelectedCurrencyPairs() {
        menuCurrencyPairs = menuCurrencyPairs.compactMap { currencyPair in
            if let newCurrencyPair = availableCurrencyPairs.first(where: { $0 == currencyPair }) {
                return newCurrencyPair
            }
            // 其他匹配逻辑
            if (currencyPair.quoteCurrency.code == "USDT" || currencyPair.quoteCurrency.code == "USD"),let newCurrencyPair = availableCurrencyPairs.first(where: {
                $0.baseCurrency == currencyPair.baseCurrency &&
                ($0.quoteCurrency.code == "USD" || $0.quoteCurrency.code == "USDT")
            }) {
                return newCurrencyPair
            }
            return nil
        }
        
        // 如果没有选择任何币种，选择默认币种 - 修复三元运算符错误
        if menuCurrencyPairs.count == 0 {
            let localCurrency = Currency(code: Locale.current.currencyCode)
            // 修复的逻辑：先尝试匹配本地货币，然后尝试USD，最后使用第一个可用的币种对
            let currencyPair: CurrencyPair?
            if let localMatch = availableCurrencyPairs.first(where: { $0.quoteCurrency == localCurrency }) {
                currencyPair = localMatch
            } else if let usdMatch = availableCurrencyPairs.first(where: { $0.quoteCurrency.code == "USD" }) {
                currencyPair = usdMatch
            } else {
                currencyPair = availableCurrencyPairs.first
            }
            
            if let currencyPair = currencyPair {
                menuCurrencyPairs.append(currencyPair)
            }
        }
    }
    
    override internal func fetch() {
        
//        guard !TickerConfig.userDefaultsFetchCoingeckoCoinIds.isEmpty else { return }
//        
//        let coinIDs = TickerConfig.userDefaultsFetchCoingeckoCoinIds.joined(separator: ",")
//        
//        let quoteCurrencies = "usd"
//
        guard !menuCurrencyPairs.isEmpty else { return }
        let coinIDs = menuCurrencyPairs.map { $0.customCode }.joined(separator: ",")
        let quoteCurrencies = Set(menuCurrencyPairs.map { $0.quoteCurrency.code.lowercased() }).joined(separator: ",")
        
        // 修复语句分隔符错误
        let apiPath = String(format: Constants.PriceAPIPathFormat, coinIDs, quoteCurrencies)
        TrackingUtils.logWithStack(apiPath)
        
        requestAPI(apiPath).map { [weak self] result in
            guard let strongSelf = self else { return }
            for currencyPair in strongSelf.menuCurrencyPairs {
                let coinID = currencyPair.customCode
                let quoteCode = currencyPair.quoteCurrency.code.lowercased()
                if let price = result.json[coinID][quoteCode].double {
                    strongSelf.setPrice(price, for: currencyPair)
                }
                
                // Store 24h price change
                let changeKey = "\(quoteCode)_24h_change"
//                print("changeKey:\(changeKey), change:\(result.json[coinID][changeKey].double)")
                if let priceChange = result.json[coinID][changeKey].double {
                    print(coinID, ", printChange:", priceChange)
                    
                    strongSelf.priceChanges[coinID] = priceChange
                }
            }
            
            strongSelf.onFetchComplete()
        }.catch { error in
            print("Error fetching CoinGecko prices: \(error)")
        }
    }
    
    // Add method to get price change for a currency pair
        func priceChange(for currencyPair: CurrencyPair) -> Double {
            return priceChanges[currencyPair.customCode] ?? 0
        }
}
