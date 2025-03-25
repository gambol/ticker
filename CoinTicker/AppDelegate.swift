

import Cocoa
import Alamofire
//import AppCenter
//import AppCenterAnalytics
//import AppCenterCrashes

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet private weak var mainMenu: NSMenu!
    @IBOutlet private weak var exchangeMenuItem: NSMenuItem!
    @IBOutlet private weak var updateIntervalMenuItem: NSMenuItem!
    @IBOutlet private weak var currencyStartSeparator: NSMenuItem!
    @IBOutlet private weak var showIconMenuItem: NSMenuItem!
    @IBOutlet private weak var quitMenuItem: NSMenuItem!
    private var currencyMenuItems = [NSMenuItem]()
    private var currencyFormatter = NumberFormatter()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()!

    public var currentExchange: Exchange!
    
    public var cryptoSelectionPopover: NSPopover?
    private var eventMonitor: Any?

    // MARK: NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Start AppCenter
//        if let resourceURL = Bundle.main.url(forResource: "appcenter", withExtension: "secret") {
//            do {
//                let appSecret = try String.init(contentsOf: resourceURL, encoding: .utf8)
//                AppCenter.start(withAppSecret: appSecret.trimmingCharacters(in: .whitespacesAndNewlines), services: [
//                    Analytics.self,
//                    Crashes.self
//                ])
//            } catch {
//                print("Error loading AppCenter app secret: \(error)")
//            }
//        }

        // Listen to workspace status notifications
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWorkspaceWillSleep(notification:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWorkspaceDidWake(notification:)), name: NSWorkspace.didWakeNotification, object: nil)

        // Set the main menu
        statusItem.menu = mainMenu

        // Load defaults
        currentExchange = TickerConfig.defaultExchange
        currentExchange.delegate = self
//        exchangeMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == currentExchange.site.rawValue ? .on : .off) })
//        updateIntervalMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == currentExchange.updateInterval ? .on : .off )})
        showIconMenuItem.state = (TickerConfig.showsIcon ? .on : .off)
        

        // Listen for network status
        let reachabilityQueue = DispatchQueue(label: "cointicker.reachability", qos: .utility, attributes: [.concurrent])
        reachabilityManager.startListening(onQueue: reachabilityQueue) { [weak self] status in
            if status == .reachable(.ethernetOrWiFi) || status == .reachable(.cellular) {
                self?.currentExchange?.load()
            } else {
                self?.currentExchange?.stop()
                self?.updateMenuWithOfflineText()
            }
        }

        if !reachabilityManager.isReachable {
            updateMenuWithOfflineText()
        }
    }

    


    // 显示币种选择弹窗
    @IBAction func showCryptoSelectionPopover(_ sender: NSMenuItem) {

        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        if let cryptoSelectionVC = storyboard.instantiateController(withIdentifier: "CryptoSelectionViewController") as? CryptoSelectionViewController {
            
            let viewLoaded = cryptoSelectionVC.view != nil

            
            // Popover创建与配置
            if cryptoSelectionPopover == nil {

                cryptoSelectionPopover = NSPopover()
                cryptoSelectionPopover?.behavior = .transient
                // 添加关闭通知监听
                NotificationCenter.default.addObserver(self,
                                                      selector: #selector(popoverDidClose(_:)),
                                                      name: NSPopover.didCloseNotification,
                                                      object: nil)
                
                
//                print("✓ 新popover已创建")
            }// 设置内容视图控制器
            cryptoSelectionPopover?.contentViewController = cryptoSelectionVC
            
            
            //           print("发送者: \(sender), 边界: \(sender.bounds),窗口: \(String(describing: sender.window))")// 显示popover
            if let statusBarButton = statusItem.button {
                if let popover = cryptoSelectionPopover {
                    popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .minY)
                    
//                    print("✓ 已调用popover.show方法")
                    
                    // 显示后检查
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                        print("Popover是否显示: \(popover.isShown)")
//                    }
                }
            }
            
//            print("Popover尺寸: \(cryptoSelectionPopover?.contentSize ?? .zero)")
            
        }

    }
    
    func closeCryptoSelectionPopover(_ sender: Any) {
        // 关闭弹窗
        cryptoSelectionPopover?.close()
        
        // 如果是从视图控制器调用的，应用用户选择
        if let cryptoVC = sender as? CryptoSelectionViewController {
//            applySelectedCurrencies(cryptoVC.tempSelectedCurrencies)
        }
    }

    
    @objc func popoverDidClose(_ notification: Notification) {
        // 确保是我们的 popover
        if let closedPopover = notification.object as? NSPopover,
           closedPopover == cryptoSelectionPopover,
           let cryptoVC = closedPopover.contentViewController as? CryptoSelectionViewController {
            
//            TickerConfig.savePopoverSelection(cryptoVC.tempSelectedCurrencies)
//            TickerConfig.saveFetchCoinIds(cryptoVC.tempSelectedCoinGeckoIds)
            applySelectedMenuBarCurrencies(cryptoVC.tempSelectedCurrencies)
            updateMenuItems()
        }
    }
    
    
    func applicationWillTerminate(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self) // 添加这一行
        
        currentExchange?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
    }

    // MARK: Notifications
    @objc private func onWorkspaceWillSleep(notification: Notification) {
        currentExchange?.stop()
    }

    @objc private func onWorkspaceDidWake(notification: Notification) {
        currentExchange?.fetch()
    }

    // MARK: UI Helpers
    private func updateMenuWithOfflineText() {
        DispatchQueue.main.async {
            self.statusItem.title = NSLocalizedString("menu.label.offline", comment: "Label to display when network connection fails")
            let image = TickerConfig.LogoImage
            image.isTemplate = true
            self.statusItem.image = image
        }
    }

    // MARK: UI Actions
    @IBAction private func onSelectExchangeSite(sender: AnyObject) {
//        if let menuItem = sender as? NSMenuItem, let exchangeSite = ExchangeSite(rawValue: menuItem.tag) {
//            if exchangeSite != currentExchange.site {
//                // End current exchange
//                currentExchange.stop()
//
//                // Deselect all exchange menu items and select this one
//                exchangeMenuItem.submenu?.items.forEach({ $0.state = .off })
//                menuItem.state = .on
//
//                // Remove all currency selections
//                currencyMenuItems.forEach({ mainMenu.removeItem($0) })
//                currencyMenuItems.removeAll()
//
//                // Start new exchange
//                let selectedCurrencyPairs = currentExchange.selectedCurrencyPairs
//                currentExchange = exchangeSite.exchange(delegate: self)
//                currentExchange.selectedCurrencyPairs = selectedCurrencyPairs
//                currentExchange.load()
//
//                // Save new data
//                TickerConfig.save(currentExchange)
//
//                // Track analytics
//                TrackingUtils.didSelectExchange(menuItem.title)
//            }
//        }
    }

    @IBAction private func onSelectUpdateInterval(sender: AnyObject) {
        // 废弃
//        if let menuItem = sender as? NSMenuItem {
//            // Reset exchange fetching
//            currentExchange.updateInterval = menuItem.tag
//            currentExchange.reset()
//
//            // Deselect all update interval menu items and select this one
//            updateIntervalMenuItem.submenu?.items.forEach({ $0.state = .off })
//            menuItem.state = .on
//
//            // Save new data
//            TickerConfig.save(currentExchange)
//        }
    }

    @objc private func onSelectQuoteCurrency(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }

        if let baseCurrency = menuItem.parent?.representedObject as? Currency, let quoteCurrency = menuItem.representedObject as? Currency, currentExchange.statusBarCurrencyPairs.count > 1 || currentExchange.statusBarCurrencyPairs.first != CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency) {
            // Reset exchange fetching
            currentExchange.toggleStatusBarCurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)

            // Update menus
            updateMenuItems()

            // Save new data
            TickerConfig.save(currentExchange)
        }
    }

    @IBAction private func onToggleShowIcon(sender: AnyObject) {
        let shouldShowMenuIcon = !TickerConfig.showsIcon
        showIconMenuItem.state = (shouldShowMenuIcon ? .on : .off)
        TickerConfig.showsIcon = shouldShowMenuIcon

        updateMenuIcon()
        updatePrices()

        TrackingUtils.didShowIcon(shouldShowMenuIcon)
    }

    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

    private func menuItem(forQuoteCurrency quoteCurrency: Currency) -> NSMenuItem {
        let item = NSMenuItem(title: quoteCurrency.displayName, action: #selector(self.onSelectQuoteCurrency(sender:)), keyEquivalent: "")
        item.representedObject = quoteCurrency
        let image = quoteCurrency.smallIconImage ?? TickerConfig.SmallLogoImage
        image.isTemplate = !quoteCurrency.isPhysical
        item.image = image
        return item
    }

    private func menuItem(forBaseCurrency baseCurrency: Currency) -> NSMenuItem {
        let item = NSMenuItem(title: baseCurrency.displayName, action: nil, keyEquivalent: "")
        item.representedObject = baseCurrency
        let image = baseCurrency.smallIconImage ?? TickerConfig.SmallLogoImage
        image.isTemplate = true
        item.image = image
        return item
    }

    fileprivate func updateMenuItems() {
        DispatchQueue.main.async {
            self.currencyMenuItems.forEach({ self.mainMenu.removeItem($0) })
            self.currencyMenuItems.removeAll()

            let indexOffset = self.mainMenu.index(of: self.currencyStartSeparator)
            
            // 获取从popover中选择的币种列表
            let selectedFromPopover = TickerConfig.selectedCurrencyCodesFromPopover
            
            // 用于跟踪已添加的币种代码，防止重复
            var addedCurrencyCodes = Set<String>()
            
            // 只为用户在popover中选择的币种创建菜单项
            for currencyPair in self.currentExchange.availableCurrencyPairs {
                let baseCurrency = currencyPair.baseCurrency
                let code = currencyPair.baseCurrency.code
                
                // 跳过已添加的币种
                if addedCurrencyCodes.contains(code) {
                    continue
                }
                
                // 只处理在popover中选择的币种
                if selectedFromPopover.contains(code) {
                    addedCurrencyCodes.insert(code)
                    let quoteCurrency = currencyPair.quoteCurrency
                    
                    // 创建带复选框的菜单项
                    let menuItem = NSMenuItem(title: "", action: #selector(self.onToggleCurrencyDisplay(_:)), keyEquivalent: "")
                    menuItem.target = self
                    // 使用 representedObject 存储货币对信息
                    menuItem.representedObject = currencyPair
                    
                    // 根据是否选择在menubar中显示设置复选框状态
                    let isSelected = self.currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency)
                    menuItem.state = isSelected ? .on : .off
                    
                    // 获取价格并格式化
                    let price = self.currentExchange.price(for: currencyPair)
                    let priceString = self.stringForPrice(price, in: quoteCurrency)
                    
                    // 获取价格变化百分比
                    var priceChangeText = ""
                    var priceChangeColor = NSColor.textColor
                    
                    if let coinGecko = self.currentExchange as? CoinGecko {
                        let priceChange = coinGecko.priceChange(for: currencyPair)
                        let sign = priceChange >= 0 ? "+" : ""
                        priceChangeText = "\(sign)\(String(format: "%.1f", priceChange))%"
                        priceChangeColor = priceChange >= 0 ? NSColor.systemGreen : NSColor.systemRed
                    }
                    
                    // 创建更美观的格式化菜单项
                    let attributedString = self.createFormattedMenuTitle(
                        code: currencyPair.baseCurrency.code,
                        price: priceString,
                        priceChange: priceChangeText,
                        priceChangeColor: priceChangeColor
                    )
                    
                    menuItem.attributedTitle = attributedString
                    
                    // 添加图标（如果有）
                    let image = baseCurrency.smallIconImage ?? TickerConfig.SmallLogoImage
                    image.isTemplate = true
                    menuItem.image = image
                    
                    self.currencyMenuItems.append(menuItem)
                    self.mainMenu.insertItem(menuItem, at: self.currencyMenuItems.count + indexOffset)
                }
            }

//            self.updateMenuIcon()
            self.updatePrices()
        }
    }

    // 创建更美观的格式化菜单项标题
    private func createFormattedMenuTitle(code: String, price: String, priceChange: String, priceChangeColor: NSColor) -> NSAttributedString {
        // 使用单空间字体确保更好的对齐效果
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // 计算每列的宽度
        let codeWidth = 6  // 币种代码通常是3-4个字符
        let priceWidth = 12 // 价格列宽度
        
        // 格式化代码和价格，确保固定宽度
        let formattedCode = code.padding(toLength: codeWidth, withPad: " ", startingAt: 0)
        
        // 创建属性字符串
        let attributedString = NSMutableAttributedString()
        
        // 添加代码部分
        attributedString.append(NSAttributedString(
            string: formattedCode,
            attributes: [.font: font]
        ))
        
        let formattedPrice = price.padding(toLength: priceWidth, withPad: " ", startingAt: 0)
        // 添加价格部分
        attributedString.append(NSAttributedString(
            string: formattedPrice,
            attributes: [.font: font]
        ))
        
        // 添加固定宽度的空格分隔符
        attributedString.append(NSAttributedString(
            string: "  ",
            attributes: [.font: font]
        ))
        
        // 添加价格变化部分（带颜色）
        attributedString.append(NSAttributedString(
            string: priceChange,
            attributes: [
                .font: font,
                .foregroundColor: priceChangeColor
            ]
        ))
        
        return attributedString
    }


    
    // Add new method to toggle currency display in menubar
    @objc private func onToggleCurrencyDisplay(_ sender: NSMenuItem) {
        guard let currencyPair = sender.representedObject as? CurrencyPair else { return }
        
        let baseCurrency = currencyPair.baseCurrency
        let quoteCurrency = currencyPair.quoteCurrency
        
        // Toggle selection state
        currentExchange.toggleStatusBarCurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
        
        // Update menu item state
        sender.state = currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency) ? .on : .off
        
        // Save new data
        TickerConfig.save(currentExchange)
        
        // Update prices display in menubar
        updatePrices()
        
        // Update menu items and prices
        updateMenuItems()
    }

    // Update the updatePrices method to only show selected currencies in menubar
    fileprivate func updatePrices() {
        DispatchQueue.main.async {
            let priceStrings = self.currentExchange.statusBarCurrencyPairs.map { currencyPair -> String in
                let price = self.currentExchange.price(for: currencyPair)
                let priceString = self.stringForPrice(price, in: currencyPair.quoteCurrency)
                
                // If only showing one currency and icon is enabled, just show price
                if self.currentExchange.isSingleBaseCurrencySelected && TickerConfig.showsIcon {
                    return priceString
                }
                
                // Otherwise show code and price
                return "\(currencyPair.baseCurrency.code): \(priceString)"
            }

            let title = priceStrings.joined(separator: " ")
            if title.isEmpty {
                let image = TickerConfig.LogoImage
                image.isTemplate = true
                self.statusItem.image = image
                
            }
            self.statusItem.title = title
            
                // 添加判断，如果title长度为0，则显示"TICK"
        }
    }
    

    private func updateMenuIcon() {
        if TickerConfig.showsIcon {
            let iconImage: NSImage
            if self.currentExchange.isSingleBaseCurrencySelected, let image = self.currentExchange.statusBarCurrencyPairs.first!.baseCurrency.iconImage {
                iconImage = image
            } else {
                iconImage = TickerConfig.LogoImage
            }

            iconImage.isTemplate = true
            self.statusItem.image = iconImage
        } else {
            self.statusItem.image = nil
        }
    }

    private func stringForPrice(_ price: Double, in quoteCurrency: Currency) -> String {
        guard price >= 0 else {
            return NSLocalizedString("menu.label.loading", comment: "Label displayed when network requests are loading")
        }

        self.currencyFormatter.numberStyle = .currency
        self.currencyFormatter.currencyCode = quoteCurrency.code
        self.currencyFormatter.currencySymbol = quoteCurrency.symbol

        var numFractionDigits = 0
        if price < 0.001 {
            // Convert to satoshi if dealing with a small Bitcoin value
            if quoteCurrency.isBitcoin {
                // ex: 5,910 sat
                self.currencyFormatter.currencyCode = ""
                self.currencyFormatter.currencySymbol = ""
                self.currencyFormatter.minimumFractionDigits = 0
                self.currencyFormatter.maximumFractionDigits = 0
                return "\(self.currencyFormatter.string(for: price * 1e8)!) sat"
            } else if price > 0 {
                // ex: 0.0007330
                numFractionDigits = 6
            }
        } else if price < 0.01 {
            // ex: 0.009789
            numFractionDigits = 4
        } else if price < 0.1 {
            // ex: 0.04500
            numFractionDigits = 3
        } else if price < 1 {
            // ex: 0.1720
            numFractionDigits = 2
        } else if price < 10 {
            // ex: 9.506
            numFractionDigits = 1
        } else {
            // ex: 14,560.00
            numFractionDigits = 0
        }

        self.currencyFormatter.currencySymbol = "$"
        
        self.currencyFormatter.minimumFractionDigits = numFractionDigits
        self.currencyFormatter.maximumFractionDigits = numFractionDigits
        return self.currencyFormatter.string(for: price)!
    }

//    fileprivate func updatePrices() {
//        DispatchQueue.main.async {
//            let priceStrings = self.currentExchange.selectedCurrencyPairs.map { currencyPair -> String in
//                let price = self.currentExchange.price(for: currencyPair)
//                let priceString = self.stringForPrice(price, in: currencyPair.quoteCurrency)
//                if self.currentExchange.isSingleBaseCurrencySelected && TickerConfig.showsIcon {
//                    return priceString
//                }
//
//                return "\(currencyPair.baseCurrency.code): \(priceString)"
//            }
//
//            self.statusItem.title = priceStrings.joined(separator: " • ")
//        }
//    }

}

extension AppDelegate: ExchangeDelegate {

    func exchange(_ exchange: Exchange, didUpdateAvailableCurrencyPairs availableCurrencyPairs: [CurrencyPair]) {
        updateMenuItems()
    }

    func exchangeDidUpdatePrices(_ exchange: Exchange) {
        updatePrices()
        // Update menu items and prices
        updateMenuItems()
    }
    
    func applySelectedCurrencies(_ selectedCurrencyCodes: Set<String>) {
        // Clear current selections
        let currentSelected = currentExchange.statusBarCurrencyPairs
        // 这个是开关. 开一个 关一个
        for pair in currentSelected {
            currentExchange.toggleStatusBarCurrencyPair(baseCurrency: pair.baseCurrency, quoteCurrency: pair.quoteCurrency)
        }
        
        // Apply new selections
        for code in selectedCurrencyCodes {
            if let currencyPair = currentExchange.availableCurrencyPairs.first(where: { $0.baseCurrency.code == code }) {
                // Get default quote currency (USD/USDT)
                let quoteCurrency = currencyPair.quoteCurrency
                currentExchange.toggleStatusBarCurrencyPair(baseCurrency: currencyPair.baseCurrency, quoteCurrency: quoteCurrency)
            }
        }
        
        // Save new data
        TickerConfig.save(currentExchange)
        
        // Update menu items and prices
        updateMenuItems()
        
        updatePrices()
    }
    
    
    // menubar 是全集
    func applySelectedMenuBarCurrencies(_ selectedCurrencyCodes: Set<String>) {
        currentExchange.saveAllMenuCurrencyPair(selectedCurrencyCodes)
        
        TickerConfig.savePopoverSelection(selectedCurrencyCodes)
        
        // Update menu items and prices
        updateMenuItems()
        
        updatePrices()
        
        // Save new data
        TickerConfig.save(currentExchange)
    }

}
