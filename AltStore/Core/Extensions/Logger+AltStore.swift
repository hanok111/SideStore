//
//  Logger+AltStore.swift
//  AltStore
//
//  Created by Riley Testut on 10/2/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

@_exported import OSLog

public extension Logger
{
    static let altstoreSubsystem = "com.rileytestut.AltStore" // Hardcoded because Bundle.main.bundleIdentifier is different for every user
    
    static let main = Logger(subsystem: altstoreSubsystem, category: "Main")
    static let sideload = Logger(subsystem: altstoreSubsystem, category: "Sideload")
    static let altjit = Logger(subsystem: altstoreSubsystem, category: "AltJIT")
}

public extension OSLogEntryLog.Level
{
    var localizedName: String {
        switch self
        {
        case .undefined: return NSLocalizedString("未定义", comment: "")
        case .debug: return NSLocalizedString("调试", comment: "")
        case .info: return NSLocalizedString("信息", comment: "")
        case .notice: return NSLocalizedString("通知", comment: "")
        case .error: return NSLocalizedString("错误", comment: "")
        case .fault: return NSLocalizedString("故障", comment: "")
        @unknown default: return NSLocalizedString("未知", comment: "")
        }
    }
}
