//
//  SystemInfo.swift
//  web-container
//
//  Created by ihugo on 2021/1/16.
//

import Foundation
import UIKit

struct SystemInfo: Codable {
    let SDKVersion: String
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let safeArea: [String: CGFloat]?
    let theme: String
    
    static func getInfo() -> SystemInfo {
        let sdkVersion = "0.1"
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        var theme = "light"
        if #available(iOS 12.0, *) {
            if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
                theme = "dark"
            }
        }
        var safeArea: [String: CGFloat]? = nil
        if let safeAreaInsets = UIApplication.shared.delegate?.window??.safeAreaInsets {
            var data = [String: CGFloat]()
            data["top"] = safeAreaInsets.top
            data["left"] = safeAreaInsets.left
            data["bottom"] = safeAreaInsets.bottom
            data["right"] = safeAreaInsets.right
            
            safeArea = data
        }

        let info = SystemInfo(SDKVersion: sdkVersion, screenWidth: screenWidth, screenHeight: screenHeight, safeArea: safeArea, theme: theme)

        return info
    }
    
    func jsonString() -> String? {
        guard let encodedData = try? JSONEncoder().encode(self) else { return nil }
        
        let jsonString = String(data: encodedData, encoding: .utf8)
        return jsonString
    }
}
