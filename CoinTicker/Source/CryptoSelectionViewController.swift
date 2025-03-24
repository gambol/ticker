//
//  CryptoSelectionViewController.swift
//  CoinTicker
//
//  Created by Zh zack on 24/3/2025.
//  Copyright © 2025 Alec Ananian. All rights reserved.
//

// CryptoSelectionViewController.swift
import Cocoa

class CryptoSelectionViewController: NSViewController {
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var hideUnselectedCheckbox: NSButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    weak var appDelegate: AppDelegate?
    
    private var allCurrencyPairs = [CurrencyPair]()
    private var filteredCurrencyPairs = [CurrencyPair]()
    // 添加临时存储用户选择
    public var tempSelectedCurrencies = Set<String>() // 存储币种代码
    
    override func viewDidLoad() {
        super.viewDidLoad()// 配置表格视图
        tableView.delegate = self
        tableView.dataSource = self// 从AppDelegate获取当前交易所数据
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            self.appDelegate = appDelegate
            
            // 直接使用所有可用的币种对
            allCurrencyPairs = appDelegate.currentExchange.availableCurrencyPairs
            
            // 如果需要去重，可以这样做
            let uniquePairs = Dictionary(grouping: allCurrencyPairs) { $0.baseCurrency.code }
                .compactMapValues { $0.first }
                .values
                .sorted()
            
            allCurrencyPairs = Array(uniquePairs)
            filteredCurrencyPairs = allCurrencyPairs
            
            for pair in appDelegate.currentExchange.selectedCurrencyPairs {
                            tempSelectedCurrencies.insert(pair.baseCurrency.code)
                        }
            
            print("Loaded \(allCurrencyPairs.count) currency pairs")
            tableView.reloadData()
        }
        
        print("crypto view get datasource")
        // 注册搜索框变更通知
        NotificationCenter.default.addObserver(self, selector: #selector(searchTextChanged),
                                               name: NSControl.textDidChangeNotification,
                                               object: searchField)
        
        
        // 设置表格视图样式
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.rowHeight = 25
        tableView.backgroundColor = NSColor.clear
        tableView.enclosingScrollView?.borderType = .noBorder
        tableView.enclosingScrollView?.hasVerticalScroller = true
        tableView.enclosingScrollView?.hasHorizontalScroller = false
        
        tableView.tableColumns.forEach { column in
            if column.identifier.rawValue == "code" {
                column.width = 80// 设置适当的宽度
            } else if column.identifier.rawValue == "name" {
                column.width = 250
            }
        }
        tableView.rowHeight = 24

        for (index, column) in tableView.tableColumns.enumerated() {
            let headerCell = column.headerCell
            switch index {
            case 0: headerCell.stringValue = ""// 复选框列
            case 1: headerCell.stringValue = "Code"
            case 2: headerCell.stringValue = "Name"
            default: break
            }
        }

        // 设置弹窗大小
        preferredContentSize = NSSize(width: 400, height: 400)
          print("CryptoSelectionViewController的视图已加载")
          // 检查表格视图是否正确连接
          print("tableView存在: \(tableView != nil)")
        
        
    }
    
    @objc func searchTextChanged(_ notification: Notification) {
        updateFilteredCurrencies()
    }
    
    @IBAction func hideUnselectedChanged(_ sender: NSButton) {
        updateFilteredCurrencies()
    }
    
    
    override func viewWillAppear() {
        super.viewWillAppear()
        print("➡️ CryptoSelectionViewController - viewWillAppear")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        print("➡️ CryptoSelectionViewController - viewDidAppear")
    }

    override func loadView() {
        super.loadView()
        print("➡️ CryptoSelectionViewController - loadView")
    }
    
    
    private func updateFilteredCurrencies() {
        let searchText = searchField.stringValue.lowercased()
        let hideUnselected = hideUnselectedCheckbox.state == .on
        
        filteredCurrencyPairs = allCurrencyPairs.filter { pair in
            // 如果选择了"hide unselected"，只显示已选择的币种
            if hideUnselected && !tempSelectedCurrencies.contains(pair.baseCurrency.code) {
                return false
            }
            
            // 处理搜索过滤
            if !searchText.isEmpty {
                return pair.baseCurrency.code.lowercased().contains(searchText) ||
                       pair.baseCurrency.displayName.lowercased().contains(searchText)
            }
            
            return true
        }
        
        tableView.reloadData()
    }

    
//    // 在自定义视图控制器中实现此方法
//    override func viewServiceDidTerminateWithError(_ error: Error) {
//        print("View service terminated with error: \(error)")
//        // 执行必要的清理或恢复操作
//    }
    
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource
extension CryptoSelectionViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        print("number of Rows. count:", filteredCurrencyPairs.count)
        return filteredCurrencyPairs.count
    }
        
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredCurrencyPairs.count else { return nil }
        let currencyPair = filteredCurrencyPairs[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        // 创建新的单元格视图或获取现有的
        let cellIdentifier = NSUserInterfaceItemIdentifier(identifier + "Cell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        // 如果单元格不存在，创建新的
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
        }
        
        switch identifier {
        case "checkbox":
            // 移除现有子视图，确保不重复添加
            cellView?.subviews.forEach { $0.removeFromSuperview() }
            
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxClicked(_:)))

            // 使用临时存储来确定复选框状态
            checkbox.state = tempSelectedCurrencies.contains(currencyPair.baseCurrency.code) ? .on : .off
            
            checkbox.tag = row
            // 添加复选框并设置约束
            cellView?.addSubview(checkbox)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                checkbox.centerXAnchor.constraint(equalTo: cellView!.centerXAnchor),
                checkbox.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
            
            return cellView
            
        case "code":
            // 移除现有子视图
            cellView?.subviews.forEach { $0.removeFromSuperview() }
            
            // 创建文本字段
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.stringValue = currencyPair.baseCurrency.code
            textField.alignment = .left
            
            // 添加到单元格并设置约束
            cellView?.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
            
            // 设置单元格的文本字段属性（重要！）
            cellView?.textField = textField
            
            return cellView
            
        case "name":
            // 移除现有子视图
            cellView?.subviews.forEach { $0.removeFromSuperview() }// 创建文本字段
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.stringValue = currencyPair.baseCurrency.displayName
            textField.alignment = .left
            
            // 添加到单元格并设置约束
            cellView?.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])// 设置单元格的文本字段属性（重要！）
            cellView?.textField = textField
            
            return cellView
        default:
            return nil
        }
    }
    
    
//    
//    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        guard row < filteredCurrencyPairs.count else { return nil }
//        let currencyPair = filteredCurrencyPairs[row]
//        let identifier = tableColumn?.identifier.rawValue ?? ""
//        
//        let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier + "Cell"), owner: self) as? NSTableCellView ?? NSTableCellView()
//        
//        switch identifier {
//        case "checkbox":
//            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxClicked(_:)))
//            checkbox.state = appDelegate?.currentExchange.isCurrencyPairSelected(baseCurrency: currencyPair.baseCurrency) ?? false ? .on : .off
//            checkbox.tag = row
//            cellView.addSubview(checkbox)
//            checkbox.frame = cellView.bounds
//            checkbox.autoresizingMask = [.width, .height]
//            return cellView
//        case "code":
//            print("当前code值: \(currencyPair.baseCurrency.code)")
//            print("textField是否存在: \(cellView.textField != nil)")
//            if let textField = cellView.textField {
//                print("textField当前属性: frame=\(textField.frame), hidden=\(textField.isHidden), textColor=\(textField.textColor)")
//            }
//            cellView.textField?.stringValue = currencyPair.baseCurrency.code
//            print("设置后的值: \(cellView.textField?.stringValue ?? "nil")")
//            return cellView
//            
//        case "name":
//            cellView.textField?.stringValue = currencyPair.baseCurrency.displayName
//            return cellView
//            
//        default:
//            return nil
//        }
//    }
    
    @objc func checkboxClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredCurrencyPairs.count else { return }
        
        let currencyPair = filteredCurrencyPairs[row]
        let currencyCode = currencyPair.baseCurrency.code
        
        // 更新临时存储而不是直接更新 currentExchange
        if sender.state == .on {
            tempSelectedCurrencies.insert(currencyCode)
        } else {
            tempSelectedCurrencies.remove(currencyCode)
        }
        
        // 如果启用了"hide unselected"，更新过滤列表
        if hideUnselectedCheckbox.state == .on {
            updateFilteredCurrencies()
        } else {
            // 否则只更新当前行
            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
        }
    }

}
