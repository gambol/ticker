//
//  TrackingUtils.swift
//  CoinTicker
//
//  Created by Alec Ananian on 7/23/17.
//  Copyright © 2017 Alec Ananian.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Cocoa
//import AppCenterAnalytics

enum TrackedEvent: String {
    case selectExchange = "Select Exchange"
    case selectUpdateInterval = "Select Update Interval"
    case selectCurrencyPair = "Select Currency Pair"
    case deselectCurrencyPair = "Deselect Currency Pair"
    case showIcon = "Show Icon"
    case hideIcon = "Hide Icon"
}

enum TrackedEventAttributes: String {
    case country = "Country"
    case exchange = "Exchange"
    case updateInterval = "Update Interval"
    case currency = "Currency"
    case currencyPair = "Currency Pair"
}

struct TrackingUtils {

    static func log(_ event: TrackedEvent, withAttributes attributes: [String: String]? = nil) {
//        Analytics.trackEvent(event.rawValue, withProperties: attributes)
    }

    static func didSelectExchange(_ exchangeName: String) {
        log(.selectExchange, withAttributes: [TrackedEventAttributes.exchange.rawValue: exchangeName])
    }

    static func didSelectUpdateInterval(_ updateInterval: Int) {
        log(.selectUpdateInterval, withAttributes: [TrackedEventAttributes.updateInterval.rawValue: String(updateInterval)])
    }

    static func didSelectCurrencyPair(_ currencyPair: CurrencyPair) {
        log(.selectCurrencyPair, withAttributes: [TrackedEventAttributes.currencyPair.rawValue: String(describing: currencyPair)])
    }

    static func didDeselectCurrencyPair(_ currencyPair: CurrencyPair) {
        log(.deselectCurrencyPair, withAttributes: [TrackedEventAttributes.currencyPair.rawValue: String(describing: currencyPair)])
    }

    static func didShowIcon(_ showing: Bool) {
        if showing {
            log(.showIcon)
        } else {
            log(.hideIcon)
        }
    }
    
    static func logWithStack(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // 获取并格式化当前时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = dateFormatter.string(from: Date())
        
        // 获取文件名（不含路径）
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        // 打印时间、文件名、函数名和行号
        print("[\(timeString)] \(fileName):\(line) \(function) - \(message)")
        
        // 打印完整的调用堆栈（跳过前两个）
        let stackSymbols = Thread.callStackSymbols.dropFirst(2).prefix(5)
        if !stackSymbols.isEmpty {
            print("  Call Stack:")
            for (index, symbol) in stackSymbols.enumerated() {
                // 简化但保留更多信息
                let parts = symbol.split(separator: " ").filter { !$0.isEmpty }
                if parts.count >= 4 {
                    // 通常格式是: "2   AppName  0x00000001234  AppName.ClassName.methodName + 123"
                    let moduleIndex = 0
                    let addressIndex = 2
                    let symbolIndex = 3
                    
                    let module = parts[moduleIndex]
                    let address = parts[addressIndex]
                    let symbolInfo = parts[symbolIndex...].joined(separator: " ")
                    
                    print("    \(index): \(module) - \(symbolInfo) [\(address)]")
                } else {
                    print("    \(index): \(symbol)")
                }
            }
        }
    }


}
