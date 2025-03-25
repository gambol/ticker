
import Foundation
import Cocoa
import Starscream
import Alamofire
import SwiftyJSON
import PromiseKit

enum ExchangeSite: Int, Codable {
    case bibox = 100
    case binance = 200
    case bitfinex = 205
    case bithumb = 207
    case bitstamp = 210
    case bittrex = 225
    case bitz = 230
    case btcturk = 233
    case coincheck = 235
    case coinone = 237
    case gateio = 239
    case gdax = 240
    case hitbtc = 241
    case huobi = 243
    case korbit = 245
    case kraken = 250
    case kucoin = 255
    case lbank = 260
    case okex = 275
    case paribu = 290
    case poloniex = 300
    case upbit = 350
    case zb = 400

    func exchange(delegate: ExchangeDelegate? = nil) -> Exchange {
        return CoinGecko(delegate: delegate)
//        switch self {
//        case .bibox: return BiboxExchange(delegate: delegate)
//        case .binance: return BinanceExchange(delegate: delegate)
//        case .bitfinex: return BitfinexExchange(delegate: delegate)
//        case .bithumb: return BithumbExchange(delegate: delegate)
//        case .bitstamp: return BitstampExchange(delegate: delegate)
//        case .bittrex: return BittrexExchange(delegate: delegate)
//        case .bitz: return BitZExchange(delegate: delegate)
//        case .btcturk: return BTCTurkExchange(delegate: delegate)
//        case .coincheck: return CoincheckExchange(delegate: delegate)
//        case .coinone: return CoinoneExchange(delegate: delegate)
//        case .gateio: return CoinGecko(delegate: delegate)
//        case .gdax: return GDAXExchange(delegate: delegate)
//        case .hitbtc: return HitBTCExchange(delegate: delegate)
//        case .huobi: return HuobiExchange(delegate: delegate)
//        case .korbit: return KorbitExchange(delegate: delegate)
//        case .kraken: return KrakenExchange(delegate: delegate)
//        case .kucoin: return KuCoinExchange(delegate: delegate)
//        case .lbank: return LBankExchange(delegate: delegate)
//        case .okex: return OKExExchange(delegate: delegate)
//        case .paribu: return ParibuExchange(delegate: delegate)
//        case .poloniex: return PoloniexExchange(delegate: delegate)
//        case .upbit: return UPbitExchange(delegate: delegate)
//        case .zb: return ZBExchange(delegate: delegate)
//        }
    }
}

protocol ExchangeDelegate {
    func exchange(_ exchange: Exchange, didUpdateAvailableCurrencyPairs availableCurrencyPairs: [CurrencyPair])
    func exchangeDidUpdatePrices(_ exchange: Exchange)
}

struct ExchangeAPIResponse {
    var representedObject: Any?
    var json: JSON
}

class Exchange {

    internal var site: ExchangeSite
    internal var delegate: ExchangeDelegate?
    private var requestTimer: Timer?
    var updateInterval = TickerConfig.defaultUpdateInterval
    var availableCurrencyPairs = [CurrencyPair]()
    var statusBarCurrencyPairs = [CurrencyPair]() // 展示在statusBar上的币
    var menuCurrencyPairs = [CurrencyPair]()  // 展示在menu上的币
    
    private var currencyPrices = [String: Double]()

    private lazy var apiResponseQueue: DispatchQueue = { [unowned self] in
        return DispatchQueue(label: "cointicker.\(self.site.rawValue)-api", qos: .utility, attributes: [.concurrent])
    }()

    internal var socket: WebSocket?
    internal lazy var socketResponseQueue: DispatchQueue = { [unowned self] in
        return DispatchQueue(label: "cointicker.\(self.site.rawValue)-socket")
    }()

    internal var isUpdatingInRealTime: Bool {
        return updateInterval == TickerConfig.Constants.RealTimeUpdateInterval
    }

    var isSingleBaseCurrencySelected: Bool {
        return (Set(statusBarCurrencyPairs.map({ $0.baseCurrency })).count == 1)
    }

    // MARK: Initialization
    deinit {
        stop()
    }

    init(site: ExchangeSite, delegate: ExchangeDelegate? = nil) {
        self.site = site
        self.delegate = delegate
    }

    
    
    
    // MARK: Currency Helpers
    func toggleStatusBarCurrencyPair(baseCurrency: Currency, quoteCurrency: Currency) {
        guard let currencyPair = availableCurrencyPairs.first(where: { $0.baseCurrency == baseCurrency && $0.quoteCurrency == quoteCurrency }) else {
            return
        }

        if let index = statusBarCurrencyPairs.firstIndex(of: currencyPair) {
            if statusBarCurrencyPairs.count > 0 {
                statusBarCurrencyPairs.remove(at: index)
                reset()
                TrackingUtils.didDeselectCurrencyPair(currencyPair)
            }
        } else if statusBarCurrencyPairs.count < 10 {
            statusBarCurrencyPairs.append(currencyPair)
            statusBarCurrencyPairs = statusBarCurrencyPairs.sorted()
            reset()
            TrackingUtils.didSelectCurrencyPair(currencyPair)
        }
    }
    
    // MARK: Currency Helpers
    func saveAllMenuCurrencyPair(_ selectedCurrencyCodes: Set<String>) {
        menuCurrencyPairs.removeAll()
        
        for code in selectedCurrencyCodes {
            if let currencyPair = availableCurrencyPairs.first(where: { $0.baseCurrency.code == code }) {
                // Get default quote currency (USD/USDT)
//                let quoteCurrency = currencyPair.quoteCurrency
                menuCurrencyPairs.append(currencyPair)
            }
        }
        
        menuCurrencyPairs = menuCurrencyPairs.sorted()
        
        // 添加判断，移除在menuCurrencyPairs不存在但在statusBarCurrencyPairs存在的pair
         statusBarCurrencyPairs.removeAll { pair in
             !menuCurrencyPairs.contains(pair)
         }
        
        reset()
        
    }
    

    func isCurrencyPairSelected(baseCurrency: Currency, quoteCurrency: Currency? = nil) -> Bool {
        if let quoteCurrency = quoteCurrency {
            return statusBarCurrencyPairs.contains(where: { $0.baseCurrency == baseCurrency && $0.quoteCurrency == quoteCurrency })
        }

        return statusBarCurrencyPairs.contains(where: { $0.baseCurrency == baseCurrency })
    }

    func statusBarCurrencyPairs(withCustomCode customCode: String) -> CurrencyPair? {
        return statusBarCurrencyPairs.first(where: { $0.customCode == customCode })
    }

    func menuCurrencyPairs(withCustomCode customCode: String) -> CurrencyPair? {
        return menuCurrencyPairs.first(where: { $0.customCode == customCode })
    }
    
    internal func setPrice(_ price: Double, for currencyPair: CurrencyPair) {
        currencyPrices[currencyPair.customCode] = price
    }

    func price(for currencyPair: CurrencyPair) -> Double {
        return currencyPrices[currencyPair.customCode] ?? -1
    }

    // MARK: Exchange Request Lifecycle
    func load() {
        // Override
    }

    internal func load(from apiPath: String, getAvailableCurrencyPairs: @escaping (ExchangeAPIResponse) -> [CurrencyPair]) {
        requestAPI(apiPath).map { [weak self] result in
            self?.setAvailableCurrencyPairs(getAvailableCurrencyPairs(result))
        }.catch { error in
            print("Error loading exchange: \(error)")
        }
    }

    internal func setAvailableCurrencyPairs(_ availableCurrencyPairs: [CurrencyPair]) {
        self.availableCurrencyPairs = availableCurrencyPairs.sorted()
        statusBarCurrencyPairs = statusBarCurrencyPairs.compactMap { currencyPair in
            if let newCurrencyPair = self.availableCurrencyPairs.first(where: { $0 == currencyPair }) {
                return newCurrencyPair
            }

            // Keep pair selected if new exchange has USDT instead of USD or vice versa
            if currencyPair.quoteCurrency.code == "USDT" || currencyPair.quoteCurrency.code == "USD", let newCurrencyPair = self.availableCurrencyPairs.first(where: { $0.baseCurrency == currencyPair.baseCurrency && ($0.quoteCurrency.code == "USD" || $0.quoteCurrency.code == "USDT") }) {
                return newCurrencyPair
            }

            return nil
        }

        if statusBarCurrencyPairs.count == 0 {
            let localCurrency = Currency(code: Locale.current.currencyCode)
            if let currencyPair = self.availableCurrencyPairs.first(where: { $0.quoteCurrency == localCurrency }) ??
                self.availableCurrencyPairs.first(where: { $0.quoteCurrency.code == "USD" }) ??
                self.availableCurrencyPairs.first(where: { $0.quoteCurrency.code == "USDT" }) ??
                self.availableCurrencyPairs.first {
                statusBarCurrencyPairs.append(currencyPair)
            }
        }

        delegate?.exchange(self, didUpdateAvailableCurrencyPairs: self.availableCurrencyPairs)
        fetch()
    }

    internal func fetch() {
        // Override
    }

    internal func onFetchComplete() {
        delegate?.exchangeDidUpdatePrices(self)
        startRequestTimer()
    }

    internal func stop() {
        socket?.disconnect()
        requestTimer?.invalidate()
        requestTimer = nil
        Session.default.session.getTasksWithCompletionHandler({ dataTasks, _, _ in
            dataTasks.forEach({ $0.cancel() })
        })
    }

    private func startRequestTimer() {
        print("startRequestTimer")
        DispatchQueue.main.async {
            self.requestTimer = Timer.scheduledTimer(timeInterval: Double(self.updateInterval),
                                                     target: self,
                                                     selector: #selector(self.onRequestTimerFired(_:)),
                                                     userInfo: nil,
                                                     repeats: false)
        }
    }

    @objc private func onRequestTimerFired(_ timer: Timer) {
        requestTimer?.invalidate()
        requestTimer = nil
        fetch()
    }

    func reset() {
        stop()
        fetch()
    }

    // MARK: API Helpers
    internal func requestAPI(_ apiPath: String, for representedObject: Any? = nil) -> Promise<ExchangeAPIResponse> {
        return Promise { seal in
            AF.request(apiPath).responseJSON(queue: apiResponseQueue) { response in
                switch response.result {
                case .success(let value):
                    seal.fulfill(ExchangeAPIResponse(representedObject: representedObject, json: JSON(value)))
                case .failure(let error):
                    print("Error in API request: \(apiPath) \(error)")
                    seal.reject(error)
                }
            }
        }
    }

}
