//
//  AppSorting.swift
//  AltStore
//
//  Created by Riley Testut on 11/14/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public enum AppSorting: String, CaseIterable
{
    case `default`
    case name
    case developer
    case lastUpdated
    
    public var localizedName: String {
        switch self
        {
        case .default: return NSLocalizedString("默认", comment: "")
        case .name: return NSLocalizedString("名称", comment: "")
        case .developer: return NSLocalizedString("开发者", comment: "")
        case .lastUpdated: return NSLocalizedString("最近更新", comment: "")
        }
    }
    
    public var isAscending: Bool {
        switch self
        {
        case .default, .name, .developer: return true
        case .lastUpdated: return false
        }
    }
}
