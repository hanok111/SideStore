//
//  StoreCategory.swift
//  AltStore
//
//  Created by Riley Testut on 11/8/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
@preconcurrency import UIKit

public enum StoreCategory: String, CaseIterable
{
    case developer
    case entertainment
    case games
    case lifestyle
    case photoAndVideo = "photo-video"
    case social
    case utilities
    case other
    
    public var localizedName: String {
        switch self
        {
        case .developer: NSLocalizedString("开发者", comment: "")
        case .entertainment: NSLocalizedString("娱乐", comment: "")
        case .games: NSLocalizedString("游戏", comment: "")
        case .lifestyle: NSLocalizedString("生活方式", comment: "")
        case .photoAndVideo: NSLocalizedString("照片与视频", comment: "")
        case .social: NSLocalizedString("社交", comment: "")
        case .utilities: NSLocalizedString("实用工具", comment: "")
        case .other: NSLocalizedString("其他", comment: "")
        }
    }
    
    public var symbolName: String {
        switch self
        {
        case .developer: "terminal" // renamed to apple.terminal as of iOS 17
        case .games: "gamecontroller"
        case .photoAndVideo: "camera"
        case .utilities: "paperclip"
        case .other: "square.stack.3d.up"
            
        case .entertainment:
            if #available(iOS 17, *) { "movieclapper" }
            else { "tv" }
        
        case .lifestyle:
            if #available(iOS 16.1, *) { "tree" }
            else { "sun.max" }
        
        case .social:
            if #available(iOS 17.0, *) { "bubble.left.and.text.bubble.right" }
            else { "text.bubble" }
        }
    }
    
    public var filledSymbolName: String {
        switch self
        {
        case .utilities: return self.symbolName
        default: return self.symbolName + ".fill"
        }
    }
    
    public var tintColor: UIColor {
        switch self
        {
        case .developer: UIColor.systemOrange
        case .entertainment: UIColor.systemRed
        case .games: UIColor.systemPurple
        case .lifestyle: UIColor.systemGreen
        case .photoAndVideo: UIColor.systemPink
        case .social: UIColor.systemYellow
        case .utilities: UIColor.systemBlue
        case .other: UIColor.systemGray
        }
    }
}
