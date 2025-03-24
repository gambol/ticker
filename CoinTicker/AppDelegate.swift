

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

        print("➡️ 准备显示加密货币选择弹窗")
           // 调试已有popover状态
           if let existingPopover = cryptoSelectionPopover {
               print("已有popover对象: \(existingPopover), 是否已显示: \(existingPopover.isShown)")
           } else {
               print("popover对象为nil，将创建新的")
           }
           
           // 创建视图控制器前后添加日志
           print("开始创建内容视图控制器")
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        if let cryptoSelectionVC = storyboard.instantiateController(withIdentifier: "CryptoSelectionViewController") as? CryptoSelectionViewController {
            
            //           let cryptoSelectionVC = CryptoSelectionViewController(nibName: "CryptoSelectionViewController", bundle: nil)
            print("✓ 内容视图控制器已创建: \(cryptoSelectionVC)")// 测试NIB文件是否能正确加载
            print("尝试加载视图")
            let viewLoaded = cryptoSelectionVC.view != nil
            print(viewLoaded ? "✓ 视图已成功加载" : "✗ 视图加载失败")
            
            // Popover创建与配置
            if cryptoSelectionPopover == nil {
                print("创建新的popover")
                cryptoSelectionPopover = NSPopover()
                cryptoSelectionPopover?.behavior = .transient
                // 添加关闭通知监听
                NotificationCenter.default.addObserver(self,
                                                      selector: #selector(popoverDidClose(_:)),
                                                      name: NSPopover.didCloseNotification,
                                                      object: nil)
                
                
                print("✓ 新popover已创建")
            }// 设置内容视图控制器
            cryptoSelectionPopover?.contentViewController = cryptoSelectionVC
            print("✓ 已设置内容视图控制器")
            
            // 显示popover前检查
            print("准备显示popover")
            
            
            //           print("发送者: \(sender), 边界: \(sender.bounds),窗口: \(String(describing: sender.window))")// 显示popover
            if let statusBarButton = statusItem.button {
                if let popover = cryptoSelectionPopover {
                    popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .minY)
                    
                    print("✓ 已调用popover.show方法")
                    
                    // 显示后检查
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("Popover是否显示: \(popover.isShown)")
                    }
                }
            }
            
            print("Popover尺寸: \(cryptoSelectionPopover?.contentSize ?? .zero)")
            
        }

    }
    
    func closeCryptoSelectionPopover(_ sender: Any) {
        // 关闭弹窗
        cryptoSelectionPopover?.close()
        
        // 如果是从视图控制器调用的，应用用户选择
        if let cryptoVC = sender as? CryptoSelectionViewController {
            applySelectedCurrencies(cryptoVC.tempSelectedCurrencies)
        }
    }

    
    @objc func popoverDidClose(_ notification: Notification) {
        // 确保是我们的 popover
        if let closedPopover = notification.object as? NSPopover,
           closedPopover == cryptoSelectionPopover,
           let cryptoVC = closedPopover.contentViewController as? CryptoSelectionViewController {
            
            // 应用用户选择
            applySelectedCurrencies(cryptoVC.tempSelectedCurrencies)
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
        if let menuItem = sender as? NSMenuItem, let exchangeSite = ExchangeSite(rawValue: menuItem.tag) {
            if exchangeSite != currentExchange.site {
                // End current exchange
                currentExchange.stop()

                // Deselect all exchange menu items and select this one
                exchangeMenuItem.submenu?.items.forEach({ $0.state = .off })
                menuItem.state = .on

                // Remove all currency selections
                currencyMenuItems.forEach({ mainMenu.removeItem($0) })
                currencyMenuItems.removeAll()

                // Start new exchange
                let selectedCurrencyPairs = currentExchange.selectedCurrencyPairs
                currentExchange = exchangeSite.exchange(delegate: self)
                currentExchange.selectedCurrencyPairs = selectedCurrencyPairs
                currentExchange.load()

                // Save new data
                TickerConfig.save(currentExchange)

                // Track analytics
                TrackingUtils.didSelectExchange(menuItem.title)
            }
        }
    }

    @IBAction private func onSelectUpdateInterval(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            // Reset exchange fetching
            currentExchange.updateInterval = menuItem.tag
            currentExchange.reset()

            // Deselect all update interval menu items and select this one
            updateIntervalMenuItem.submenu?.items.forEach({ $0.state = .off })
            menuItem.state = .on

            // Save new data
            TickerConfig.save(currentExchange)
        }
    }

    @objc private func onSelectQuoteCurrency(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }

        if let baseCurrency = menuItem.parent?.representedObject as? Currency, let quoteCurrency = menuItem.representedObject as? Currency, currentExchange.selectedCurrencyPairs.count > 1 || currentExchange.selectedCurrencyPairs.first != CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency) {
            // Reset exchange fetching
            currentExchange.toggleCurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)

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
            var menuMapping = [String: NSMenuItem]()
            self.currentExchange.availableCurrencyPairs.forEach { currencyPair in
                let baseCurrency = currencyPair.baseCurrency
                let quoteCurrency = currencyPair.quoteCurrency
                if !baseCurrency.isPhysical {
                    let menuItem: NSMenuItem
                    if let savedMenuItem = menuMapping[baseCurrency.code] {
                        menuItem = savedMenuItem
                    } else {
                        menuItem = self.menuItem(forBaseCurrency: baseCurrency)
                        menuItem.state = (self.currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency) ? .on : .off)
                        menuItem.submenu = NSMenu()
                        menuMapping[baseCurrency.code] = menuItem
                        self.currencyMenuItems.append(menuItem)
                        self.mainMenu.insertItem(menuItem, at: menuMapping.count + indexOffset)
                    }

                    let submenuItem = self.menuItem(forQuoteCurrency: quoteCurrency)
                    submenuItem.state = (self.currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency) ? .on : .off)
                    menuItem.submenu!.addItem(submenuItem)
                }
            }

            self.updateMenuIcon()
            self.updatePrices()
        }
    }

    private func updateMenuIcon() {
        if TickerConfig.showsIcon {
            let iconImage: NSImage
            if self.currentExchange.isSingleBaseCurrencySelected, let image = self.currentExchange.selectedCurrencyPairs.first!.baseCurrency.iconImage {
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

        self.currencyFormatter.minimumFractionDigits = numFractionDigits
        self.currencyFormatter.maximumFractionDigits = numFractionDigits
        return self.currencyFormatter.string(for: price)!
    }

    fileprivate func updatePrices() {
        DispatchQueue.main.async {
            let priceStrings = self.currentExchange.selectedCurrencyPairs.map { currencyPair -> String in
                let price = self.currentExchange.price(for: currencyPair)
                let priceString = self.stringForPrice(price, in: currencyPair.quoteCurrency)
                if self.currentExchange.isSingleBaseCurrencySelected && TickerConfig.showsIcon {
                    return priceString
                }

                return "\(currencyPair.baseCurrency.code): \(priceString)"
            }

            self.statusItem.title = priceStrings.joined(separator: " • ")
        }
    }

}

extension AppDelegate: ExchangeDelegate {

    func exchange(_ exchange: Exchange, didUpdateAvailableCurrencyPairs availableCurrencyPairs: [CurrencyPair]) {
        updateMenuItems()
    }

    func exchangeDidUpdatePrices(_ exchange: Exchange) {
        updatePrices()
    }
    
    func applySelectedCurrencies(_ selectedCurrencyCodes: Set<String>) {
            // 清除当前所有选择
            let currentSelected = currentExchange.selectedCurrencyPairs
            for pair in currentSelected {
                currentExchange.toggleCurrencyPair(baseCurrency: pair.baseCurrency, quoteCurrency: pair.quoteCurrency)
            }
            
            // 应用新的选择
            for code in selectedCurrencyCodes {
                if let currencyPair = currentExchange.availableCurrencyPairs.first(where: { $0.baseCurrency.code == code }) {
                    // 获取默认报价货币 (USD/USDT)
                    let quoteCurrency = currencyPair.quoteCurrency
                    currentExchange.toggleCurrencyPair(baseCurrency: currencyPair.baseCurrency, quoteCurrency: quoteCurrency)
                }
            }
            
            // 保存新数据
            TickerConfig.save(currentExchange)
            
            // 更新菜单项和价格
            updateMenuItems()
        }

}
